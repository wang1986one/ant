local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local mu = mathpkg.util

local HOMOGENEOUS_DEPTH, ORIGIN_TOP_LEFT = math3d.homogeneous_depth, not math3d.origin_bottom_left

local function line_zplane_intersection(A, B, zDistance)
    local pn = math3d.vector(0.0, 0.0, 1.0)
    local ab = math3d.sub(B, A)
    local pnDotA = math3d.dot(pn, A)
    local pnDotab = math3d.dot(pn, ab)
    local t = (zDistance - pnDotA) / pnDotab
    return math3d.muladd(t, ab, A)
end

local function screen2view(screen, screensize, invproj)
    local screen_ndc = {screen[1]/screensize[1], screen[2]/screensize[2]}
    screen_ndc[1] = screen_ndc[1] * 2.0 - 1.0
    screen_ndc[2] = screen_ndc[2] * 2.0 - 1.0
    if ORIGIN_TOP_LEFT then
        screen_ndc[2] = 1.0 - screen_ndc[2];
    end

    local ndc = {screen_ndc[1], screen_ndc[2], screen[3], screen[4]};
    local clip = math3d.transform(invproj, ndc, 1);
    local clipv = math3d.index(clip, 4)
    clip = math3d.mul(clip, 1.0/clipv)
    return clip
end

local u_cluster_size<const> = {16, 9, 24}

local function which_z(u_nearZ, u_farZ, depth_slice, num_slice)
    return u_nearZ*((u_farZ/u_nearZ) ^ (depth_slice/num_slice))
end

-- dispatch as: [16, 9, 24]
local function build_aabb(id, screensize, u_nearZ, u_farZ, invproj)
    local near_sS = HOMOGENEOUS_DEPTH and -1.0 or 0.0

    local tileunit<const> = {screensize[1]/u_cluster_size[1], screensize[2]/u_cluster_size[2]}

    local x, y  = id[1] * tileunit[1], id[2] * tileunit[2]
    local nx, ny= x + tileunit[1], y + tileunit[1]

    local corners_near_sS = {
        {x, y, near_sS, 1.0},
        {nx, y, near_sS, 1.0},
        {x, ny, near_sS, 1.0},
        {nx, ny, near_sS, 1.0},
    }

    local eyepos = math3d.vector(0, 0, 0)

    local depth         = which_z(u_nearZ, u_farZ, id[3],     u_cluster_size[3]);
    local depth_next    = which_z(u_nearZ, u_farZ, id[3]+1,   u_cluster_size[3]);

    local min_vS, max_vS

    local function merge_aabb(minv, maxv, p)
        local v = math3d.tovalue(p)
        if minv == nil then
            return v, v
        end

        return mu.min(minv, v), mu.max(maxv, v)
    end
    for _, v in ipairs(corners_near_sS) do
        local v_vS = screen2view(v, screensize, invproj)
        local p0 = line_zplane_intersection(eyepos, v_vS, depth)
        local p1 = line_zplane_intersection(eyepos, v_vS, depth_next)

        min_vS, max_vS = merge_aabb(min_vS, max_vS, p0)
        min_vS, max_vS = merge_aabb(min_vS, max_vS, p1)
    end

    return {
        minv = min_vS,
        maxv = max_vS,
    }
end

local function linear_depth(nolinear_depth, u_nearZ, u_farZ)
    local z_n, A, B
    if HOMOGENEOUS_DEPTH then
        z_n = 2.0 * nolinear_depth - 1.0;
        A = (u_farZ + u_nearZ) / (u_farZ - u_nearZ);
        B = -2.0 * u_farZ * u_nearZ/(u_farZ - u_nearZ);
    else
        z_n = nolinear_depth;
        A = u_farZ / (u_farZ - u_nearZ);
        B = -(u_farZ * u_nearZ) / (u_farZ - u_nearZ);
    end
    local z_e = B / (z_n - A);
    return z_e;
end

local function which_cluster_Z(nolineardepth, u_nearZ, u_farZ, u_slice_scale, u_slice_bias)
    local ldepth = linear_depth(nolineardepth, u_nearZ, u_farZ)
    local logdepth = math.log(ldepth, 2)
    return math.floor(math.max(logdepth * u_slice_scale + u_slice_bias, 0.0)+0.5);
end
    
local function which_cluster(fragcoord, screensize, u_nearZ, u_farZ, u_slice_scale, u_slice_bias)
    local tileunit = {screensize[1]/u_cluster_size[1], screensize[2]/u_cluster_size[2]}
    local cluster_z = math.floor(math.max(math.log(linear_depth(fragcoord[3], u_nearZ, u_farZ), 2) * u_slice_scale + u_slice_bias, 0.0)+0.5);
    local cluster_coord= {
        math.floor((fragcoord[1]/tileunit[1])+0.5),
        math.floor((fragcoord[2]/tileunit[2])+0.5),
        cluster_z,
    }
    return 	cluster_coord[1] +
            u_cluster_size[1] * cluster_coord[2] +
            (u_cluster_size[1] * u_cluster_size[2]) * cluster_coord[3], cluster_coord
end

return {
    which_cluster_Z = which_cluster_Z,
    which_z = which_z,
    which_cluster = which_cluster,
    build = build_aabb,
    build_all = function (screensize, nearZ, farZ, invproj)
        local cluster_aabbs = {}
        for z=1, u_cluster_size[3] do
            for y=1, u_cluster_size[2] do
                for x=1, u_cluster_size[3] do
                    local id = {x-1, y-1, z-1}
                    local cluster_idx = math3d.dot(id, math3d.vector(1, u_cluster_size[1], u_cluster_size[1] * u_cluster_size[2]))
                    local aabb = {}
                    build_aabb(id, screensize, nearZ, farZ, invproj, aabb)
                    cluster_aabbs[cluster_idx] = aabb
                end
            end
        end

        return cluster_aabbs
    end
}
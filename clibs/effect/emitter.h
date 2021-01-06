#pragma once
#include "particle.h"

class particle_emitter {
public:
    particle_emitter() = default;
    bool update(float dt);
    bool isdead() const { return mlife.isdead(); }
    uint32_t spawn(const glm::mat4 &transform, uint8_t materialidx);

private:
    void step(float dt);
    bool update_lifetime(float dt) { return mlife.update(dt); }
public:
    struct spawndata {
        spawndata() : count(0), rate(1.f){}
        //TODO: we need interp spawn count by lifetime
        uint32_t    count;
        float       rate;

        struct init_attributes{
            interpolation::init_valueT<float>   life;
            interpolation::f3_init_value        velocity;
            interpolation::f3_init_value        acceleration;
            interpolation::f3_init_value        scale;
            interpolation::f3_init_value        translation;
            interpolation::init_valueT<float>   rotation;
            interpolation::uv_motion_init_value uv_motion;
            interpolation::uv_motion_init_value subuv_motion;
            interpolation::color_init_value     color;
            materialdata                        material;

            comp_ids components;
        };

        struct interp_attributes{
            interpolation::f3_interpolator      velocity;
            interpolation::f3_interpolator      acceleration;
            interpolation::f3_interpolator      scale;
            interpolation::f3_interpolator      translation;
            interpolation::interp_valueT<float> rotation;
            // interpolation::f2_interpolator      uv_motion;
            // interpolation::f2_interpolator     subuv_motion;
            interpolation::color_interpolator   color;

            comp_ids components;
        };

        init_attributes     init;
        interp_attributes   interp;

        // step data
        struct step_data{
            step_data() : count(0), loop(0.f){}
            uint32_t    count;
            float       loop;
        };
        step_data step;
    };
    spawndata   mspawn;
    lifedata    mlife;
};
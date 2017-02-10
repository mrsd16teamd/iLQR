function [ x_new ] = dynamics_finite( x, u, dt, params)
%DYNAMICS_FINITE Runge-Kutta integration to discretize dynamics
%   Detailed explanation goes here

if ~exist('param','var')
    k1 = dynamics(x, u);
    k2 = dynamics(x + 0.5 * dt * k1, u);
    k3 = dynamics(x + 0.5 * dt * k2, u);
    k4 = dynamics(x + dt * k3, u);
else
    k1 = dynamics(x, u, params);
    k2 = dynamics(x + 0.5 * dt * k1, u, params);
    k3 = dynamics(x + 0.5 * dt * k2, u, params);
    k4 = dynamics(x + dt * k3, u, params);
end

x_new = x + (dt / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4);

end

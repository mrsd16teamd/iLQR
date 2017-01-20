clear all;

% The planning horizon
T = 5;
dt = 0.1;

global NUM_CTRL;
NUM_CTRL = round(T / dt); % number of controls.

% The dimension of the state space
global X_DIM

% The dimension of the control space
global U_DIM

% The step size for finite differencing
global DEFAULTSTEPSIZE;
DEFAULTSTEPSIZE = 0.01;

%% Initialize warmup trajectory
Uc = ones(U_DIM, NUM_CTRL);
Uc(1,:) = Uc(1,:) * 0.0;
Uc(2,:) = Uc(2,:) * 3.0;

x_null = zeros(X_DIM, 1);
u_null = zeros(U_DIM, 1);

%% Core iLQR routine
lamb_factor = 2;
lamb = 1.0;
lamb_max = 10000000;

eps_converge = 1E-4;

max_iter_num = 200;
iter_num = 0;

progress_cnt = 0;
last_progress_made = 1;

% Do forward pass to get current state Xc
Xc = ForwardShoot(Uc, x_start, dt);
while (iter_num < max_iter_num)
    iter_num = iter_num + 1;
    
    % update f_x, f_u, l_x, l_u, l_xx, l_ux, l_uu
    f_x = zeros(X_DIM, X_DIM, NUM_CTRL);
    f_u = zeros(X_DIM, U_DIM, NUM_CTRL);
    l = zeros(1, NUM_CTRL+1);
    l_x = zeros(X_DIM, NUM_CTRL+1);
    l_u = zeros(U_DIM, NUM_CTRL+1);
    l_xx = zeros(X_DIM, X_DIM, NUM_CTRL+1);
    l_ux = zeros(U_DIM, X_DIM, NUM_CTRL+1);
    l_uu = zeros(U_DIM, U_DIM, NUM_CTRL+1);
    
    for t = 1 : NUM_CTRL
        x_c = Xc(:, t);
        u_c = Uc(:, t);
        
        f_x(:, :, t) = eye(X_DIM, X_DIM) + calc_df_dx(x_c, u_c) * dt;
        f_u(:, :, t) = calc_df_du(x_c, u_c) * dt;
        
        l(t) = calc_l(x_c, u_c) * dt;
        l_x(:, t) = calc_dl_dx(x_c, u_c) * dt;
        l_u(:, t) = calc_dl_du(x_c, u_c) * dt;
        l_xx(:, :, t) = calc_ddl_dxdx(x_c, u_c) * dt;
        l_ux(:, :, t) = calc_ddl_dudx(x_c, u_c) * dt;
        l_uu(:, :, t) = calc_ddl_dudu(x_c, u_c) * dt;
    end
    x_c = Xc(:, NUM_CTRL+1);
    % set for time ell, f_x & f_u are set to zeros
    l(NUM_CTRL+1) = calc_l(x_c, u_null) * dt;
    l_x(:,NUM_CTRL+1) = calc_dl_dx(x_c, u_null) * dt;
    l_u(:,NUM_CTRL+1) = u_null;
    l_xx(:,:, NUM_CTRL+1) = calc_ddl_dxdx(x_c, u_null) * dt;
    l_ux(:,:, NUM_CTRL+1) = zeros(U_DIM, X_DIM);
    l_uu(:,:, NUM_CTRL+1) = zeros(U_DIM, U_DIM);
    
    % Do a backward pass, estimate the value function and the dynamics.
    k = zeros(U_DIM, NUM_CTRL+1);
    K = zeros(U_DIM, X_DIM, NUM_CTRL+1);
    
    V_x = l_x(:, NUM_CTRL+1);
    V_xx = l_xx(:, :, NUM_CTRL+1);
    
    for t = NUM_CTRL : -1 : 1
        Q_x = l_x(:, t) + f_x(:, :, t)' * V_x;
        Q_u = l_u(:, t) + f_u(:, :, t)' * V_x;
        
        Q_xx = l_xx(:, :, t) + f_x(:, :, t)' * V_xx * f_x(:, :, t);
        Q_ux = l_ux(:, :, t) + f_u(:, :, t)' * V_xx * f_x(:, :, t);
        Q_uu = l_uu(:, :, t) + f_u(:, :, t)' * V_xx * f_u(:, :, t);

        [U_Q_uu, s_Q_uu, V_Q_uu] = svd(Q_uu);
        s_Q_uu = diag(s_Q_uu);
        s_Q_uu = max(s_Q_uu, 0);
        s_Q_uu = s_Q_uu + lamb;
        
        Q_uu_inv = U_Q_uu' * diag(1.0./s_Q_uu) * V_Q_uu';
        
        k(:, t) = -Q_uu_inv * Q_u;
        K(:, :, t) = -Q_uu_inv * Q_ux;
        
        % update V
        V_x = Q_x - K(:, :, t)' * Q_uu * k(:, t);
        V_xx = Q_xx - K(:, :, t)' * Q_uu * K(:, :, t);
    end
    
    [Xn, Un] = ForwardShootOpt(Xc, Uc, k, K, x_start, dt);
    
    Jc = calc_J(Xc, Uc);
    Jn = calc_J(Xn, Un);
    
    % Use Levenberg-Marquardt heuristics, needs current cost and next cost
    if (Jn < Jc)
        fprintf('Iter %d: %0.2f -> %0.2f, GOOD :)\n', iter_num, Jc, Jn)
        lamb = lamb / lamb_factor;
        Xc = Xn;
        Uc = Un;
        
        if (iter_num > 1 && (abs(Jn - Jc) / Jn) < eps_converge)
            display('iLQR successful converged.\n')
            break;
        end
        
        last_progress_made = 1;
    else
        fprintf('Iter %d: %0.2f -> %0.2f, BAD :(\n', iter_num, Jc, Jn)
        
        lamb = lamb * lamb_factor;
        Xc = Xc;
        Uc = Uc;
        if (lamb > lamb_max)
            display('iLQR failed to converge.\n')
            break;
        end
        
        last_progress_made = 0;
    end
end


%% The result will be in [Xc, Uc] upon successful convergence









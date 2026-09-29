/**
 * PM2 process file.
 *  Vertical scaling:   cluster mode runs one worker per CPU core ("max"); bigger VPS → more workers.
 *  Horizontal scaling: workers are stateless (JWT auth, MySQL job state, Redis shared cache/limits),
 *                      so you can run this same file on more servers behind nginx's upstream.
 *  Zero downtime:      `pm2 reload` restarts workers one at a time; wait_ready waits for process.send('ready').
 */
module.exports = {
  apps: [
    {
      name: 'billfixer-api',
      script: 'src/server.js',
      cwd: __dirname,
      exec_mode: 'cluster',
      instances: process.env.PM2_INSTANCES || 'max',
      node_args: '--max-old-space-size=512',
      max_memory_restart: '600M',
      wait_ready: true,
      listen_timeout: 15000,
      kill_timeout: 25000,
      min_uptime: '20s',
      max_restarts: 50,
      exp_backoff_restart_delay: 200,
      time: true,
      merge_logs: true,
      out_file: './logs/api.out.log',
      error_file: './logs/api.err.log',
      env: { NODE_ENV: 'production' },
    },
  ],
};

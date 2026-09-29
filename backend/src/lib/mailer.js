import nodemailer from 'nodemailer';
import { config } from '../config/index.js';
import { logger } from './logger.js';

let transport = null;
if (config.smtp.enabled) {
  transport = nodemailer.createTransport({
    host: config.smtp.host,
    port: config.smtp.port,
    secure: config.smtp.port === 465,
    auth: { user: config.smtp.user, pass: config.smtp.password },
    pool: true,
    maxConnections: 3,
    connectionTimeout: 10_000,
    socketTimeout: 15_000,
  });
}

export const mailEnabled = () => Boolean(transport);

export async function sendMail({ to, subject, text }) {
  if (!transport) throw new Error('SMTP not configured');
  try {
    await transport.sendMail({ from: config.smtp.from, to, subject, text });
  } catch (err) {
    logger.error({ err: err.message }, 'email send failed');
    throw err;
  }
}

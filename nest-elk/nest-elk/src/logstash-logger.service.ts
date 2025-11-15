import { Injectable } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class LogstashLoggerService {
  private readonly logstashUrl =
    process.env.LOGSTASH_URL || 'http://logstash:5044/logs';

  async log(
    level: 'INFO' | 'ERROR' | 'WARN' | 'DEBUG',
    message: string,
    meta: any = {},
  ) {
    const payload = {
      level,
      message,
      meta,
      timestamp: new Date().toISOString(),
      app: 'nest-elk-demo',
    };

    try {
      await axios.post(this.logstashUrl, payload);
    } catch (err) {
      // console.error('Failed to send log to Logstash', err);
    }
  }
}

import { Controller, Get, InternalServerErrorException } from '@nestjs/common';
import { LogstashLoggerService } from './logstash-logger.service';

@Controller()
export class AppController {
  constructor(private readonly logstashLogger: LogstashLoggerService) {}

  @Get('ok')
  async ok() {
    await this.logstashLogger.log('INFO', 'OK endpoint called', {
      path: '/ok',
    });
    return { status: 'ok' };
  }

  @Get('error')
  async error() {
    await this.logstashLogger.log('ERROR', 'Error endpoint called', {
      path: '/error',
    });
    throw new InternalServerErrorException('Simulated error');
  }
}

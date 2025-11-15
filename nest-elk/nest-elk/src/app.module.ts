import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { LogstashLoggerService } from './logstash-logger.service';

@Module({
  imports: [],
  controllers: [AppController],
  providers: [LogstashLoggerService],
})
export class AppModule {}

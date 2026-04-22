import { assertConfig, config } from './config';
import { createApp } from './app';

assertConfig();

const app = createApp();

app.listen(config.port, () => {
  console.log(`API listening on port ${config.port}`);
});

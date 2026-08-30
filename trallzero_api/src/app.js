import express from 'express';
import cors from 'cors';

import routes from './routers/index.js';

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Rotas da aplicação
app.use('/api', routes);

// Rota de verificação (Health Check)
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'success', message: 'API TrallZero funcionando perfeitamente!' });
});

export default app;

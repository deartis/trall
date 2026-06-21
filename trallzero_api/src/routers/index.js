import { Router } from 'express';

const router = Router();

import userRoutes from './userRoutes.js';
import alertRoutes from './alertRoutes.js';
import routeRoutes from './routeRoutes.js';

router.use('/users', userRoutes);
router.use('/alerts', alertRoutes);
router.use('/routes', routeRoutes);

export default router;

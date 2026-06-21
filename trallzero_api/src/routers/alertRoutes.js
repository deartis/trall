import { Router } from 'express';
import { createAlert, getAlerts, validateAlert } from '../controllers/alertController.js';

const router = Router();

router.post('/', createAlert);
router.get('/', getAlerts);
router.post('/:id/validate', validateAlert); // Rota para votar em um alerta

export default router;

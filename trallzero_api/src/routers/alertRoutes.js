import { Router } from 'express';
import { createAlert, getAlerts, validateAlert, deleteAlert } from '../controllers/alertController.js';

const router = Router();

router.post('/', createAlert);
router.get('/', getAlerts);
router.post('/:id/validate', validateAlert); // Rota para votar em um alerta
router.delete('/:id', deleteAlert);          // Rota para excluir um alerta

export default router;

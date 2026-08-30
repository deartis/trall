import { Router } from 'express';
import { createUser, getUsers, googleLogin, getUserProfile, getRanking } from '../controllers/userController.js';

const router = Router();

router.post('/', createUser);
router.get('/', getUsers);
router.get('/ranking', getRanking);          // Ranking comunitário (Top XP)
router.get('/:id', getUserProfile);          // Perfil com pontuação do usuário
router.post('/google-login', googleLogin);   // Login/cadastro via Google

export default router;

import { Router } from 'express';
import { createUser, getUsers, googleLogin } from '../controllers/userController.js';

const router = Router();

router.post('/', createUser);
router.get('/', getUsers);
router.post('/google-login', googleLogin); // Login/cadastro via Google

export default router;

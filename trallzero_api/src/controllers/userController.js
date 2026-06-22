import prisma from '../services/prisma.js';

export const createUser = async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    // Obs: Em um ambiente real a senha precisa ser "hasheada" (ex: bcrypt)
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password, 
      },
    });

    res.status(201).json({ success: true, data: user });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

export const getUsers = async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
        // Não retornar a senha
      }
    });
    res.status(200).json({ success: true, data: users });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Login ou cadastro via Google (upsert pelo email)
export const googleLogin = async (req, res) => {
  try {
    const { googleId, email, name } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, error: 'email é obrigatório' });
    }

    // Cria se não existe, retorna se já existe
    const user = await prisma.user.upsert({
      where: { email },
      update: { name: name ?? email }, // Atualiza nome se mudou
      create: {
        name: name ?? email,
        email,
        password: googleId ?? 'google-oauth', // Senha dummy, não usada com OAuth
      },
    });

    res.status(200).json({ success: true, data: user });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};


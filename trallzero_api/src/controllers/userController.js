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
        xp: true,
        reportsCount: true,
        confirmationsCount: true,
        correctionsCount: true,
        createdAt: true,
      }
    });
    res.status(200).json({ success: true, data: users });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Obter perfil e pontuação de um usuário específico
export const getUserProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({
      where: { id: parseInt(id) },
      select: {
        id: true,
        name: true,
        email: true,
        xp: true,
        reportsCount: true,
        confirmationsCount: true,
        correctionsCount: true,
        createdAt: true,
      },
    });

    if (!user) {
      return res.status(404).json({ success: false, error: 'Usuário não encontrado' });
    }

    res.status(200).json({ success: true, data: user });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Ranking comunitário dos melhores motoristas (Top 20 por XP)
export const getRanking = async (req, res) => {
  try {
    const topUsers = await prisma.user.findMany({
      orderBy: { xp: 'desc' },
      take: 20,
      select: {
        id: true,
        name: true,
        xp: true,
        reportsCount: true,
        confirmationsCount: true,
      },
    });

    res.status(200).json({ success: true, data: topUsers });
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
      select: {
        id: true,
        name: true,
        email: true,
        xp: true,
        reportsCount: true,
        confirmationsCount: true,
        correctionsCount: true,
        createdAt: true,
      }
    });

    res.status(200).json({ success: true, data: user });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};


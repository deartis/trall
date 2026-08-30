import prisma from '../services/prisma.js';

// Criar um novo alerta no mapa
export const createAlert = async (req, res) => {
  try {
    const { type, latitude, longitude, description, userId } = req.body;
    
    // Raio de proximidade em metros (ex: 100 metros)
    const RADIUS_METERS = 100;
    const EARTH_RADIUS = 6371000; // Raio da Terra em metros

    // Busca se já existe um alerta do mesmo tipo dentro do raio
    const nearbyAlerts = await prisma.$queryRaw`
      SELECT id, latitude, longitude 
      FROM "Alert"
      WHERE "type"::text = ${type}
        AND (
          ${EARTH_RADIUS} * acos(
            cos(radians(${latitude})) * cos(radians(latitude)) * 
            cos(radians(longitude) - radians(${longitude})) + 
            sin(radians(${latitude})) * sin(radians(latitude))
          )
        ) <= ${RADIUS_METERS}
      LIMIT 1;
    `;

    // Se encontramos um alerta idêntico por perto...
    if (nearbyAlerts.length > 0) {
      const existingAlert = nearbyAlerts[0];

      // Em vez de duplicar, adiciona uma validação (voto positivo)
      // Verifica se este usuário já votou nesse alerta antes
      const existingValidation = await prisma.validation.findFirst({
        where: {
          userId: userId,
          alertId: existingAlert.id,
        }
      });

      if (!existingValidation) {
        await prisma.validation.create({
          data: {
            isHelpful: true,
            userId: userId,
            alertId: existingAlert.id,
          }
        });

        // Pontua o usuário que confirmou presença (+5 XP)
        if (userId) {
          await prisma.user.update({
            where: { id: parseInt(userId) },
            data: {
              xp: { increment: 5 },
              confirmationsCount: { increment: 1 },
            }
          }).catch(() => null);
        }
      }

      // Busca o alerta completo com as relações atualizadas para retornar ao app
      const fullAlert = await prisma.alert.findUnique({
        where: { id: existingAlert.id },
        include: {
          user: { select: { id: true, name: true, xp: true } },
          _count: { select: { validations: true } }
        }
      });

      return res.status(200).json({ 
        success: true, 
        message: 'Alerta próximo já existente. Adicionada nova validação!',
        data: fullAlert,
        merged: true
      });
    }

    // Se não há alerta próximo, cria um novo
    const alert = await prisma.alert.create({
      data: {
        type,
        latitude,
        longitude,
        description,
        userId,
      },
      include: {
        user: { select: { id: true, name: true, xp: true } },
        _count: { select: { validations: true } }
      }
    });

    // Pontua o criador do novo alerta (+10 XP)
    let updatedUser = null;
    if (userId) {
      updatedUser = await prisma.user.update({
        where: { id: parseInt(userId) },
        data: {
          xp: { increment: 10 },
          reportsCount: { increment: 1 },
        },
        select: {
          id: true,
          xp: true,
          reportsCount: true,
          confirmationsCount: true,
        }
      }).catch(() => null);
    }

    res.status(201).json({
      success: true,
      data: alert,
      userScore: updatedUser,
      xpEarned: 10,
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Listar todos os alertas com dados de autor e nível/XP
export const getAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      include: {
        user: { select: { id: true, name: true, xp: true } }, // Traz quem criou o alerta com o XP
        _count: { select: { validations: true } } // Quantidade de votos/validações
      }
    });
    
    res.status(200).json({ success: true, data: alerts });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Validar/Votar em um alerta existente (Confirmar Presença)
export const validateAlert = async (req, res) => {
  try {
    const { id } = req.params; // ID do alerta
    const { userId, isHelpful } = req.body;
    const alertId = parseInt(id);
    const parsedUserId = parseInt(userId);

    // Evita voto duplicado do mesmo usuário no mesmo alerta
    const existing = await prisma.validation.findFirst({
      where: {
        userId: parsedUserId,
        alertId: alertId,
      }
    });

    if (existing) {
      return res.status(200).json({
        success: true,
        message: 'Você já confirmou este alerta anteriormente.',
        data: existing,
        alreadyValidated: true,
      });
    }
    
    const validation = await prisma.validation.create({
      data: {
        isHelpful: isHelpful ?? true,
        userId: parsedUserId,
        alertId: alertId,
      }
    });

    // Premia o motorista que validou (+5 XP)
    const updatedUser = await prisma.user.update({
      where: { id: parsedUserId },
      data: {
        xp: { increment: 5 },
        confirmationsCount: { increment: 1 },
      },
      select: {
        id: true,
        xp: true,
        reportsCount: true,
        confirmationsCount: true,
      }
    }).catch(() => null);

    res.status(201).json({
      success: true,
      data: validation,
      userScore: updatedUser,
      xpEarned: 5,
    });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Excluir um alerta (e suas validações em cascata)
export const deleteAlert = async (req, res) => {
  try {
    const { id } = req.params;
    const alertId = parseInt(id);

    // Deleta as validações antes (FK constraint)
    await prisma.validation.deleteMany({ where: { alertId } });

    await prisma.alert.delete({ where: { id: alertId } });

    res.status(200).json({ success: true, message: 'Alerta excluído.' });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};


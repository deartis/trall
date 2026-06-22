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
      }

      // Busca o alerta completo com as relações atualizadas para retornar ao app
      const fullAlert = await prisma.alert.findUnique({
        where: { id: existingAlert.id },
        include: {
          user: { select: { name: true } },
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
    });

    res.status(201).json({ success: true, data: alert });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Listar todos os alertas
export const getAlerts = async (req, res) => {
  try {
    const alerts = await prisma.alert.findMany({
      include: {
        user: { select: { name: true } }, // Traz quem criou o alerta
        _count: { select: { validations: true } } // Quantidade de votos/validações
      }
    });
    
    res.status(200).json({ success: true, data: alerts });
  } catch (error) {
    res.status(400).json({ success: false, error: error.message });
  }
};

// Validar/Votar em um alerta existente
export const validateAlert = async (req, res) => {
  try {
    const { id } = req.params; // ID do alerta
    const { userId, isHelpful } = req.body;
    
    const validation = await prisma.validation.create({
      data: {
        isHelpful,
        userId,
        alertId: parseInt(id),
      }
    });

    res.status(201).json({ success: true, data: validation });
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


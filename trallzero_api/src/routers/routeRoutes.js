import { Router } from 'express';
import { PrismaClient } from '@prisma/client';

const router = Router();
const prisma = new PrismaClient();

// POST /api/routes — Cria ou substitui a rota ativa do usuário
router.post('/', async (req, res) => {
  const { userId, stops, truckType, name } = req.body;

  if (!userId || !stops || !Array.isArray(stops)) {
    return res.status(400).json({ success: false, message: 'userId e stops são obrigatórios.' });
  }

  try {
    // Desativa todas as rotas ativas anteriores do usuário
    await prisma.route.updateMany({
      where: { userId, isActive: true },
      data: { isActive: false },
    });

    // Cria a nova rota com todas as paradas
    const route = await prisma.route.create({
      data: {
        userId,
        name: name ?? null,
        truckType: truckType ?? 'truck',
        isActive: true,
        stops: {
          create: stops.map((stop, index) => ({
            order: index,
            recipientName: stop.recipientName,
            address: stop.address,
            lat: stop.lat,
            lng: stop.lng,
            isCompleted: stop.isCompleted ?? false,
          })),
        },
      },
      include: { stops: { orderBy: { order: 'asc' } } },
    });

    return res.status(201).json({ success: true, data: route });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Erro interno.' });
  }
});

// GET /api/routes/active?userId=X — Busca a rota ativa do usuário
router.get('/active', async (req, res) => {
  const userId = parseInt(req.query.userId);

  if (!userId) {
    return res.status(400).json({ success: false, message: 'userId é obrigatório.' });
  }

  try {
    const route = await prisma.route.findFirst({
      where: { userId, isActive: true },
      include: { stops: { orderBy: { order: 'asc' } } },
      orderBy: { createdAt: 'desc' },
    });

    return res.json({ success: true, data: route ?? null });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Erro interno.' });
  }
});

// PATCH /api/routes/stops/:stopId — Marca uma parada como concluída ou não
router.patch('/stops/:stopId', async (req, res) => {
  const stopId = parseInt(req.params.stopId);
  const { isCompleted } = req.body;

  try {
    const stop = await prisma.routeStop.update({
      where: { id: stopId },
      data: { isCompleted: isCompleted ?? true },
    });

    return res.json({ success: true, data: stop });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Parada não encontrada.' });
  }
});

// DELETE /api/routes/active?userId=X — Encerra a rota ativa
router.delete('/active', async (req, res) => {
  const userId = parseInt(req.query.userId);

  if (!userId) {
    return res.status(400).json({ success: false, message: 'userId é obrigatório.' });
  }

  try {
    await prisma.route.updateMany({
      where: { userId, isActive: true },
      data: { isActive: false },
    });

    return res.json({ success: true, message: 'Rota encerrada.' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ success: false, message: 'Erro interno.' });
  }
});

export default router;

-- Datos de demostración (solo dev y staging; seed.sh se niega a correr en prod).
-- Idempotente: borra la demo anterior, identificada por los teléfonos +591600000XX
-- y las imágenes bajo seed/, y la vuelve a crear.

-- Los pedidos a vendedores de la demo apuntan a sus tiendas: se borran antes
-- (order_items cae en cascada) para poder borrar y recrear las tiendas.
DELETE FROM orders   WHERE seller_user_id IN (SELECT id FROM users WHERE phone LIKE '+591600000__');
DELETE FROM products WHERE seller_user_id IN (SELECT id FROM users WHERE phone LIKE '+591600000__');
DELETE FROM stores   WHERE owner_user_id  IN (SELECT id FROM users WHERE phone LIKE '+591600000__');
DELETE FROM banners  WHERE image_path LIKE 'seed/%';

INSERT INTO users (phone, display_name, city) VALUES
    ('+59160000001', 'AeroModel La Paz', 'La Paz'),
    ('+59160000002', 'Garage RC',        'Santa Cruz'),
    ('+59160000003', 'Escala 1:35',      'Cochabamba'),
    ('+59160000011', 'Jorge Quispe',     'La Paz'),
    ('+59160000012', 'Ana Rojas',        'Cochabamba')
ON CONFLICT (phone) DO UPDATE SET display_name = EXCLUDED.display_name, city = EXCLUDED.city;

INSERT INTO stores (owner_user_id, slug, name, logo_path, description, city, whatsapp_phone, delivery_options, status, is_featured)
SELECT u.id, v.slug, v.name, v.logo_path, v.description, v.city, v.phone, v.delivery::jsonb, 'approved', true
FROM (VALUES
    ('+59160000001', 'aeromodel-lapaz', 'AeroModel La Paz', 'seed/stores/aeromodel-lapaz.png',
     'Aviones RC, repuestos y accesorios para aeromodelismo. Asesoría para principiantes.',
     'La Paz', '["pickup", "local", "national"]'),
    ('+59160000002', 'garage-rc-scz', 'Garage RC', 'seed/stores/garage-rc-scz.png',
     'Autos y barcos radiocontrolados, eléctricos y a combustión. Taller de reparación.',
     'Santa Cruz', '["pickup", "local"]'),
    ('+59160000003', 'escala-135-cbba', 'Escala 1:35', 'seed/stores/escala-135-cbba.png',
     'Maquetas plásticas, pinturas y herramientas de modelismo estático.',
     'Cochabamba', '["pickup", "national"]')
) AS v (phone, slug, name, logo_path, description, city, delivery)
JOIN users u ON u.phone = v.phone;

INSERT INTO products (seller_user_id, store_id, category_id, title, description, price_bob, condition, stock, city, created_at, updated_at)
SELECT u.id, s.id, c.id, v.title, v.description, v.price, v.condition, v.stock, u.city,
       now() - v.age::interval, now() - v.age::interval
FROM (VALUES
    ('+59160000001', 'aeromodel-lapaz', 'aviones-rc', 'E-flite P-51D Mustang 1.2 m BNF Basic',
     'Warbird de 1,2 m con estabilización AS3X y SAFE Select. Ideal como segundo avión. Requiere radio y batería 4S.',
     3480.00, 'new', 3, '2 hours'),
    ('+59160000001', 'aeromodel-lapaz', 'aviones-rc', 'Spitfire Mk IX 1.2 m PNP',
     'Réplica del clásico británico con tren retráctil y flaps. Incluye motor, ESC y servos.',
     2950.00, 'new', 2, '1 day'),
    ('+59160000001', 'aeromodel-lapaz', 'accesorios', 'Dubro Kwik-Start XL con cargador USB',
     'Encendedor de bujías glow recargable por USB. Indispensable para motores a combustión.',
     240.00, 'new', 10, '3 days'),
    ('+59160000001', 'aeromodel-lapaz', 'accesorios', 'Dubro Glo-Ignitor XL',
     'Encendedor glow clásico, sin cargador. Usa batería de 1,2 V.',
     160.00, 'new', 8, '4 days'),
    ('+59160000001', 'aeromodel-lapaz', 'pinturas-herramientas', 'Dubro bidón de combustible con bomba',
     'Bidón con bomba manual para cargar combustible glow sin derrames.',
     210.00, 'new', 5, '5 days'),
    ('+59160000001', 'aeromodel-lapaz', 'drones', 'DJI Avata FPV',
     'Dron FPV cinematográfico con protección de hélices. Ideal para vuelos en interiores y exteriores.',
     7900.00, 'new', 1, '6 hours'),
    ('+59160000002', 'garage-rc-scz', 'autos-rc', 'Arrma Vorteks 4X4 3S BLX RTR',
     'Stadium truck brushless 1/10, listo para correr. Hasta 80 km/h con batería 3S.',
     3150.00, 'new', 4, '30 minutes'),
    ('+59160000002', 'garage-rc-scz', 'autos-rc', 'Tamiya Novafox 1/10 (kit)',
     'Buggy clásico 2WD para armar. Perfecto para iniciarse en el armado de autos RC.',
     1290.00, 'new', 3, '2 days'),
    ('+59160000002', 'garage-rc-scz', 'barcos', 'Pro Boat remolcador Horizon Harbor RTR',
     'Remolcador a escala con luces LED y gran estabilidad. Listo para navegar.',
     2700.00, 'new', 2, '1 day'),
    ('+59160000002', 'garage-rc-scz', 'barcos', 'Pro Boat Recoil 2 26" lancha brushless',
     'Lancha deep-V autoadrizante, ideal para lagunas. Requiere baterías 2S/4S.',
     1850.00, 'new', 2, '7 days'),
    ('+59160000003', 'escala-135-cbba', 'maquetas', 'Tamiya 1/35 M16 Multiple Gun Motor Carriage',
     'Half-track estadounidense con cuatro ametralladoras. Incluye figuras.',
     420.00, 'new', 6, '12 hours'),
    ('+59160000003', 'escala-135-cbba', 'maquetas', 'Tamiya 1/35 M3 Stuart',
     'Tanque ligero de la Segunda Guerra Mundial, kit de armado sencillo.',
     380.00, 'new', 5, '3 days'),
    ('+59160000003', 'escala-135-cbba', 'maquetas', 'Revell 1/28 Fokker Dr.I Model Set',
     'Triplano del Barón Rojo. El set incluye pinturas, pegamento y pincel.',
     360.00, 'new', 4, '4 days'),
    ('+59160000003', 'escala-135-cbba', 'maquetas', 'Revell 1/24 Mercedes-Benz SSKL Model Set',
     'Auto de carreras de 1931. El set incluye pinturas, pegamento y pincel.',
     340.00, 'new', 3, '8 days'),
    ('+59160000003', 'escala-135-cbba', 'maquetas', 'Revell 1/72 Spitfire Mk.Vb Model Set',
     'Kit básico ideal para principiantes. Incluye pinturas y pegamento.',
     180.00, 'new', 12, '9 days'),
    ('+59160000011', NULL, 'maquetas', 'Fokker Dr.I 1/28 armado y pintado',
     'Maqueta terminada a mano, con aerografía y envejecido. Se entrega con base.',
     650.00, 'used', 1, '5 hours'),
    ('+59160000011', NULL, 'maquetas', 'Messerschmitt Bf 109 1/32 armado',
     'Avión armado con detalles de cabina. Pequeño retoque en el ala izquierda.',
     520.00, 'used', 1, '2 days'),
    ('+59160000012', NULL, 'maquetas', 'Willys Jeep 1/24 armado',
     'Jeep militar terminado, pintura mate y calcas originales.',
     300.00, 'used', 1, '1 day'),
    ('+59160000012', NULL, 'maquetas', 'Sopwith Camel en madera',
     'Estructura de madera sin entelar, de exhibición. Pieza única.',
     900.00, 'used', 1, '6 days'),
    ('+59160000012', NULL, 'maquetas', 'Diligencia del oeste armada',
     'Diligencia de madera y metal armada a mano, con caballos.',
     750.00, 'used', 1, '10 days')
) AS v (phone, store_slug, category_slug, title, description, price, condition, stock, age)
JOIN users u ON u.phone = v.phone
JOIN categories c ON c.slug = v.category_slug
LEFT JOIN stores s ON s.slug = v.store_slug;

INSERT INTO product_images (product_id, path, thumb_path, sort)
SELECT p.id, 'seed/products/' || v.image || '.jpg', 'seed/products/' || v.image || '_t.jpg', v.sort
FROM (VALUES
    ('E-flite P-51D Mustang 1.2 m BNF Basic', 'eflite-p51', 0),
    ('Spitfire Mk IX 1.2 m PNP', 'spitfire-pnp', 0),
    ('Dubro Kwik-Start XL con cargador USB', 'dubro-kwikstart-usb', 0),
    ('Dubro Glo-Ignitor XL', 'dubro-glo-ignitor', 0),
    ('Dubro bidón de combustible con bomba', 'dubro-bidon', 0),
    ('DJI Avata FPV', 'dji-avata', 0),
    ('Arrma Vorteks 4X4 3S BLX RTR', 'arrma-vorteks', 0),
    ('Tamiya Novafox 1/10 (kit)', 'tamiya-novafox', 0),
    ('Pro Boat remolcador Horizon Harbor RTR', 'proboat-remolcador', 0),
    ('Pro Boat Recoil 2 26" lancha brushless', 'proboat-recoil', 0),
    ('Tamiya 1/35 M16 Multiple Gun Motor Carriage', 'tamiya-m16', 0),
    ('Tamiya 1/35 M3 Stuart', 'tamiya-m3-stuart', 0),
    ('Revell 1/28 Fokker Dr.I Model Set', 'revell-fokker', 0),
    ('Revell 1/24 Mercedes-Benz SSKL Model Set', 'revell-sskl', 0),
    ('Revell 1/72 Spitfire Mk.Vb Model Set', 'revell-spitfire', 0),
    ('Fokker Dr.I 1/28 armado y pintado', 'fokker-armado-1', 0),
    ('Fokker Dr.I 1/28 armado y pintado', 'fokker-armado-2', 1),
    ('Messerschmitt Bf 109 1/32 armado', 'bf109-armado', 0),
    ('Willys Jeep 1/24 armado', 'jeep-armado', 0),
    ('Sopwith Camel en madera', 'camel-madera-1', 0),
    ('Sopwith Camel en madera', 'camel-madera-2', 1),
    ('Diligencia del oeste armada', 'diligencia-1', 0),
    ('Diligencia del oeste armada', 'diligencia-2', 1),
    ('Diligencia del oeste armada', 'diligencia-3', 2)
) AS v (title, image, sort)
JOIN products p ON p.title = v.title
JOIN users u ON u.id = p.seller_user_id AND u.phone LIKE '+591600000__';

INSERT INTO banners (title, image_path, sort) VALUES
    ('1ra Convención Nacional de Diecast · 3 y 4 de noviembre, Cochabamba', 'seed/banners/diecast-convencion.jpg', 10),
    ('Exposición Ferrari 75 años',                                         'seed/banners/ferrari-75.jpg',        20),
    ('Arrma Fireteam: llegó el nuevo 6S',                                  'seed/banners/arrma-fireteam.jpg',    30),
    ('Carreras de drones FPV',                                             'seed/banners/drone-racing.jpg',      40);

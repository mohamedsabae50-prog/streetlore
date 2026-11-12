-- DRAFT ONLY: do not apply to production until the Play review is complete.
-- Generated from the verified local Alexandria/Cairo preview seed.
BEGIN;

ALTER TABLE public.places
  ADD COLUMN IF NOT EXISTS governorate text NOT NULL DEFAULT 'alexandria';
UPDATE public.places
SET governorate = 'alexandria'
WHERE governorate IS NULL OR btrim(governorate) = '';
ALTER TABLE public.places
  ALTER COLUMN governorate SET DEFAULT 'alexandria',
  ALTER COLUMN governorate SET NOT NULL;

ALTER TABLE public.tours
  ADD COLUMN IF NOT EXISTS governorate text NOT NULL DEFAULT 'alexandria';
UPDATE public.tours
SET governorate = 'alexandria'
WHERE governorate IS NULL OR btrim(governorate) = '';
ALTER TABLE public.tours
  ALTER COLUMN governorate SET DEFAULT 'alexandria',
  ALTER COLUMN governorate SET NOT NULL;

DO $draft$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'places_governorate_check'
      AND conrelid = 'public.places'::regclass
  ) THEN
    ALTER TABLE public.places
      ADD CONSTRAINT places_governorate_check
      CHECK (governorate IN ('alexandria', 'cairo'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'tours_governorate_check'
      AND conrelid = 'public.tours'::regclass
  ) THEN
    ALTER TABLE public.tours
      ADD CONSTRAINT tours_governorate_check
      CHECK (governorate IN ('alexandria', 'cairo'));
  END IF;
END
$draft$;

ALTER TABLE public.places
  DROP CONSTRAINT IF EXISTS places_category_check;
ALTER TABLE public.places
  ADD CONSTRAINT places_category_check CHECK (
    category IN (
      'Historical', 'Culture', 'Nature', 'Food', 'Cafe', 'Shopping',
      'Mosques', 'Churches', 'Streets', 'Hotels', 'ATM'
    )
  );

CREATE INDEX IF NOT EXISTS idx_places_governorate
  ON public.places USING btree (governorate);
CREATE INDEX IF NOT EXISTS idx_tours_governorate
  ON public.tours USING btree (governorate);

INSERT INTO public.places (
  id, name, name_en, name_ar, description, description_en, description_ar, image_url, image_urls, rating, category, category_ar, lat, lng, address, address_ar, open_hours, review_count, price_level, price_note, price_local_egp, price_foreigner_egp, is_hidden_gem, is_featured, display_order, enable_chat, enable_gallery, governorate
)
VALUES
  ('cairo_citadel', 'Salah El-Din Citadel', 'Salah El-Din Citadel', 'قلعة صلاح الدين الأيوبي', 'An Ayyubid hilltop fortress later expanded in the Ottoman era, home to the Mosque of Muhammad Ali and sweeping panoramic views across Cairo.', 'An Ayyubid hilltop fortress later expanded in the Ottoman era, home to the Mosque of Muhammad Ali and sweeping panoramic views across Cairo.', 'قلعة حصينة على التل شُيّدت في العصر الأيوبي وطُوّرت في العصر العثماني، وتضم مسجد محمد علي وتطل بإطلالات بانورامية على القاهرة.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Historical', 'تاريخي', 30.0287, 31.2599, 'Al Abageyah, Cairo', 'الأباجية، القاهرة', '8:00 AM - 5:00 PM', 12500, 'cheap', 'Paid admission; verify current ticket prices', 60, 550, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('khan_el_khalili', 'Khan El-Khalili Bazaar', 'Khan El-Khalili Bazaar', 'خان الخليلي', 'A historic Mamluk-era bazaar in Al-Gamaliya, known for brassware, lanterns, spices, traditional crafts, and heritage cafes in the heart of Islamic Cairo.', 'A historic Mamluk-era bazaar in Al-Gamaliya, known for brassware, lanterns, spices, traditional crafts, and heritage cafes in the heart of Islamic Cairo.', 'بازار تاريخي يعود إلى العصر المملوكي في الجمالية، يشتهر بالمشغولات النحاسية والفوانيس والتوابل والحرف التقليدية والمقاهي التراثية.', 'https://images.unsplash.com/photo-1531058020387-3be344556be6?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Shopping', 'تسوّق', 30.0477, 31.2623, 'Al-Gamaliya, Cairo', 'الجمالية، القاهرة', '10:00 AM - 11:00 PM', 9800, 'free', 'Free entry; purchases vary', 0, 0, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('al_muizz_street', 'Al-Muizz Street', 'Al-Muizz Street', 'شارع المعز لدين الله الفاطمي', 'An open-air museum of medieval Fatimid and Mamluk architecture, connecting Bab al-Futuh in the north with Bab Zuweila in the south.', 'An open-air museum of medieval Fatimid and Mamluk architecture, connecting Bab al-Futuh in the north with Bab Zuweila in the south.', 'متحف مفتوح للعمارة الفاطمية والمملوكية، يمتد من باب الفتوح شمالاً إلى باب زويلة جنوباً ويضم آثاراً إسلامية فريدة.', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Historical', 'تاريخي', 30.0511, 31.2616, 'Al-Gamaliya, Cairo', 'الجمالية، القاهرة', 'Open 24 hours', 7200, 'free', 'Street access is free; some monuments require tickets', 0, 0, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('egyptian_museum_tahrir', 'The Egyptian Museum in Cairo', 'The Egyptian Museum in Cairo', 'المتحف المصري بالتحرير', 'An iconic neoclassical museum on Tahrir Square with a major collection of Pharaonic antiquities spanning Egypt’s ancient dynasties.', 'An iconic neoclassical museum on Tahrir Square with a major collection of Pharaonic antiquities spanning Egypt’s ancient dynasties.', 'متحف كلاسيكي الطراز في ميدان التحرير يضم مجموعة بارزة من الآثار الفرعونية التي تمتد عبر عصور مصر القديمة.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Culture', 'ثقافة', 30.0478, 31.2336, 'Tahrir Square, Downtown Cairo', 'ميدان التحرير، وسط القاهرة', '9:00 AM - 5:00 PM', 15000, 'cheap', 'Paid admission; verify current ticket prices', 30, 450, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('nmec_fustat', 'National Museum of Egyptian Civilization (NMEC)', 'National Museum of Egyptian Civilization (NMEC)', 'المتحف القومي للحضارة المصرية', 'A Fustat museum presenting Egyptian civilization across eras, including the Royal Mummies Hall and collections from prehistoric times to the present.', 'A Fustat museum presenting Egyptian civilization across eras, including the Royal Mummies Hall and collections from prehistoric times to the present.', 'متحف في الفسطاط يعرض حضارة مصر عبر العصور، ويضم قاعة المومياوات الملكية ومجموعات تمتد من عصور ما قبل التاريخ حتى العصر الحديث.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Culture', 'ثقافة', 30.0084, 31.2482, 'Fustat, Old Cairo', 'الفسطاط، مصر القديمة', '9:00 AM - 5:00 PM', 6800, 'cheap', 'Paid admission; verify current ticket prices', 30, 500, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('cairo_tower', 'Cairo Tower', 'Cairo Tower', 'برج القاهرة', 'A 187-metre lotus-inspired tower on Gezira Island, completed in 1961, with 360-degree views over the Nile and the city.', 'A 187-metre lotus-inspired tower on Gezira Island, completed in 1961, with 360-degree views over the Nile and the city.', 'برج بارتفاع ١٨٧ متراً مستوحى من زهرة اللوتس في جزيرة الجزيرة، افتُتح عام ١٩٦١ ويوفر إطلالة بانورامية على النيل والقاهرة.', 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.5, 'Historical', 'معلم', 30.0459, 31.2243, 'Gezira Island, Zamalek, Cairo', 'جزيرة الجزيرة، الزمالك، القاهرة', '9:00 AM - 1:00 AM', 8700, 'moderate', 'Paid admission; verify current ticket prices', 70, 250, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('sultan_hassan_mosque', 'Mosque-Madrasa of Sultan Hassan', 'Mosque-Madrasa of Sultan Hassan', 'مسجد ومدرسة السلطان حسن', 'A monumental 14th-century Mamluk mosque and madrasa, celebrated for its scale and stonework opposite Citadel Square.', 'A monumental 14th-century Mamluk mosque and madrasa, celebrated for its scale and stonework opposite Citadel Square.', 'مسجد ومدرسة مملوكية ضخمة من القرن الرابع عشر، تشتهر بعظمتها ونقوشها الحجرية وتقع قبالة ميدان القلعة.', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Mosques', 'مساجد', 30.0316, 31.2561, 'Al-Khalifa, Cairo', 'الخليفة، القاهرة', '9:00 AM - 5:00 PM', 4100, 'cheap', 'Paid admission; respect prayer times', 20, 180, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('ibn_tulun_mosque', 'Mosque of Ibn Tulun', 'Mosque of Ibn Tulun', 'مسجد أحمد بن طولون', 'Founded in 879 AD, this is Cairo’s oldest intact mosque, known for its expansive courtyard and distinctive external spiral minaret.', 'Founded in 879 AD, this is Cairo’s oldest intact mosque, known for its expansive courtyard and distinctive external spiral minaret.', 'تأسس المسجد عام ٨٧٩م، ويُعد أقدم مسجد قائم في القاهرة، ويشتهر بصحنه الواسع ومئذنته الحلزونية الخارجية.', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Mosques', 'مساجد', 30.0287, 31.2494, 'Al-Sayeda Zainab, Cairo', 'السيدة زينب، القاهرة', '8:00 AM - 5:00 PM', 3200, 'free', 'Free entry; donations welcome', 0, 0, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('al_azhar_mosque', 'Al-Azhar Mosque', 'Al-Azhar Mosque', 'الجامع الأزهر', 'Founded in 970 AD as the centre of Fatimid Cairo, Al-Azhar became a world-renowned institution of Islamic learning and worship.', 'Founded in 970 AD as the centre of Fatimid Cairo, Al-Azhar became a world-renowned institution of Islamic learning and worship.', 'تأسس الجامع الأزهر عام ٩٧٠م في قلب القاهرة الفاطمية، وأصبح منارة عالمية للعلم الإسلامي ومكاناً للعبادة.', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Mosques', 'مساجد', 30.0457, 31.2627, 'Al-Azhar Street, Cairo', 'شارع الأزهر، القاهرة', 'Prayer times; visitor access varies', 5600, 'free', 'Free entry; respect prayer times and visitor guidance', 0, 0, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('hanging_church', 'The Hanging Church', 'The Hanging Church', 'الكنيسة المعلقة', 'A landmark Coptic church built above the gatehouse towers of the Roman Babylon Fortress, with a history reaching back to early Christian Cairo.', 'A landmark Coptic church built above the gatehouse towers of the Roman Babylon Fortress, with a history reaching back to early Christian Cairo.', 'كنيسة قبطية بارزة أُقيمت فوق برجي بوابة حصن بابليون الروماني، ويرتبط تاريخها ببدايات المسيحية في القاهرة.', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Churches', 'كنائس', 30.0053, 31.2302, 'Coptic Cairo, Old Cairo', 'القاهرة القبطية، مصر القديمة', '9:00 AM - 4:00 PM', 4500, 'free', 'Free entry; opening hours may vary', 0, 0, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('coptic_museum', 'Coptic Museum', 'Coptic Museum', 'المتحف القبطي', 'A museum with one of the world’s largest collections of Coptic Christian art, including woodwork, textiles, icons, and manuscripts.', 'A museum with one of the world’s largest collections of Coptic Christian art, including woodwork, textiles, icons, and manuscripts.', 'متحف يضم واحدة من أكبر مجموعات الفن القبطي المسيحي في العالم، بما فيها المشغولات الخشبية والمنسوجات والأيقونات والمخطوطات.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Culture', 'ثقافة', 30.006, 31.2305, 'Coptic Cairo, Old Cairo', 'القاهرة القبطية، مصر القديمة', '9:00 AM - 5:00 PM', 2300, 'cheap', 'Paid admission; verify current ticket prices', 10, 100, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('amr_ibn_alas_mosque', 'Mosque of Amr ibn al-As', 'Mosque of Amr ibn al-As', 'مسجد عمرو بن العاص', 'Originally founded in 641 AD in Fustat, this historic mosque is regarded as the first mosque in Egypt and Africa.', 'Originally founded in 641 AD in Fustat, this historic mosque is regarded as the first mosque in Egypt and Africa.', 'تأسس المسجد في الفسطاط عام ٦٤١م، ويُعرف بأنه أول مسجد في مصر وأفريقيا.', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Mosques', 'مساجد', 30.0101, 31.2332, 'Fustat, Old Cairo', 'الفسطاط، مصر القديمة', 'Prayer times; visitor access varies', 2800, 'free', 'Free entry; respect prayer times', 0, 0, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('baron_empain_palace', 'Baron Empain Palace', 'Baron Empain Palace', 'قصر البارون إمبان', 'A distinctive Hindu-temple-inspired palace built for Édouard Empain, founder of Heliopolis, and an architectural landmark of early 20th-century Cairo.', 'A distinctive Hindu-temple-inspired palace built for Édouard Empain, founder of Heliopolis, and an architectural landmark of early 20th-century Cairo.', 'قصر فريد مستوحى من المعابد الهندية شُيّد لإدوار إمبان مؤسس هليوبوليس، ويُعد معلماً معمارياً من أوائل القرن العشرين.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.6, 'Historical', 'تاريخي', 30.0867, 31.3303, 'El-Orouba Street, Heliopolis', 'شارع العروبة، مصر الجديدة', '9:00 AM - 6:00 PM', 3900, 'cheap', 'Paid admission; verify current ticket prices', 20, 100, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('abdeen_palace', 'Abdeen Palace Museum', 'Abdeen Palace Museum', 'متحف قصر عابدين', 'A 19th-century Khedivial royal palace in Downtown Cairo, now housing specialized museums of royal collections, arms, and historical gifts.', 'A 19th-century Khedivial royal palace in Downtown Cairo, now housing specialized museums of royal collections, arms, and historical gifts.', 'قصر ملكي خديوي من القرن التاسع عشر في وسط القاهرة، ويضم اليوم متاحف متخصصة للمقتنيات الملكية والأسلحة والهدايا التاريخية.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.5, 'Culture', 'ثقافة', 30.0429, 31.2476, 'Abdeen Square, Downtown Cairo', 'ميدان عابدين، وسط القاهرة', '9:00 AM - 3:00 PM', 1500, 'cheap', 'Paid admission; verify current visiting arrangements', 20, 100, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('al_azhar_park', 'Al-Azhar Park', 'Al-Azhar Park', 'حديقة الأزهر', 'A landscaped hilltop green space with views of the Ayyubid wall and Salah El-Din Citadel, created on the historic edge of Fatimid Cairo.', 'A landscaped hilltop green space with views of the Ayyubid wall and Salah El-Din Citadel, created on the historic edge of Fatimid Cairo.', 'مساحة خضراء منسقة على تلة تطل على سور القاهرة الأيوبي وقلعة صلاح الدين، وتقع عند الحافة التاريخية للقاهرة الفاطمية.', 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.6, 'Nature', 'طبيعة', 30.0407, 31.2657, 'Al-Darb Al-Ahmar, Cairo', 'الدرب الأحمر، القاهرة', '9:00 AM - 10:00 PM', 6100, 'cheap', 'Paid park admission; verify current prices', 25, 25, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('islamic_art_museum', 'Museum of Islamic Art', 'Museum of Islamic Art', 'متحف الفن الإسلامي', 'A leading museum in Bab Al-Khalq presenting Islamic art and craftsmanship, with notable ceramics, glass lamps, metalwork, and manuscripts.', 'A leading museum in Bab Al-Khalq presenting Islamic art and craftsmanship, with notable ceramics, glass lamps, metalwork, and manuscripts.', 'متحف رائد في باب الخلق يعرض الفن والحرف الإسلامية، ويضم قطعاً مميزة من الخزف والمصابيح الزجاجية والمعادن والمخطوطات.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Culture', 'ثقافة', 30.0444, 31.2524, 'Bab Al-Khalq, Cairo', 'باب الخلق، القاهرة', '9:00 AM - 5:00 PM', 1900, 'cheap', 'Paid admission; verify current ticket prices', 20, 100, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('gayer_anderson_museum', 'Gayer-Anderson Museum', 'Gayer-Anderson Museum', 'متحف جاير أندرسون (بيت الكريتلية)', 'Two adjoining historic houses from the 16th and 17th centuries beside Ibn Tulun Mosque, noted for Ottoman interiors and intricate mashrabiya screens.', 'Two adjoining historic houses from the 16th and 17th centuries beside Ibn Tulun Mosque, noted for Ottoman interiors and intricate mashrabiya screens.', 'بيتان تاريخيان متجاوران من القرنين السادس عشر والسابع عشر بجوار مسجد ابن طولون، يشتهران بديكورات عثمانية ومشربيات دقيقة الصنع.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.6, 'Culture', 'ثقافة', 30.0281, 31.2503, 'Al-Sayeda Zainab, Cairo', 'السيدة زينب، القاهرة', '9:00 AM - 5:00 PM', 1100, 'cheap', 'Paid admission; verify current ticket prices', 20, 60, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('manial_palace', 'Manial Palace Museum', 'Manial Palace Museum', 'متحف قصر الأمير محمد علي بالمنيل', 'A royal complex on Rhoda Island built by Prince Mohamed Ali, blending Ottoman, Moorish, and Andalusian styles with gardens and a museum.', 'A royal complex on Rhoda Island built by Prince Mohamed Ali, blending Ottoman, Moorish, and Andalusian styles with gardens and a museum.', 'مجمع ملكي في جزيرة الروضة أنشأه الأمير محمد علي، يمزج الطرز العثمانية والمغربية والأندلسية ويضم حدائق ومتحفاً.', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Culture', 'ثقافة', 30.027, 31.2292, 'Manial, Rhoda Island, Cairo', 'المنيل، جزيرة الروضة، القاهرة', '9:00 AM - 5:00 PM', 2100, 'cheap', 'Paid admission; verify current ticket prices', 20, 100, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('nile_ritz_carlton_cairo', 'The Nile Ritz-Carlton, Cairo', 'The Nile Ritz-Carlton, Cairo', 'فندق النيل ريتز كارلتون القاهرة', 'A luxury Nile-side hotel between Tahrir Square and the river, close to the Egyptian Museum and central Cairo attractions.', 'A luxury Nile-side hotel between Tahrir Square and the river, close to the Egyptian Museum and central Cairo attractions.', 'فندق فاخر على ضفاف النيل بين ميدان التحرير والنهر، بالقرب من المتحف المصري ومعالم وسط القاهرة.', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Hotels', 'فنادق', 30.0461, 31.2321, '1113 Corniche El Nil, Downtown Cairo', '١١١٣ كورنيش النيل، وسط القاهرة', 'Open 24 hours', 8500, 'expensive', 'Rates vary by date and room', 12000, 12000, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('marriott_zamalek_cairo', 'Cairo Marriott Hotel Zamalek', 'Cairo Marriott Hotel Zamalek', 'فندق ماريوت القاهرة الزمالك', 'A historic palace hotel on Gezira Island, surrounded by gardens and within easy reach of Zamalek and central Cairo.', 'A historic palace hotel on Gezira Island, surrounded by gardens and within easy reach of Zamalek and central Cairo.', 'فندق تاريخي في قصر بجزيرة الجزيرة، تحيط به الحدائق ويقع بالقرب من الزمالك ووسط القاهرة.', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.6, 'Hotels', 'فنادق', 30.0569, 31.2244, '16 Saray El Gezira Street, Zamalek', '١٦ شارع سراي الجزيرة، الزمالك', 'Open 24 hours', 9300, 'expensive', 'Rates vary by date and room', 9000, 9000, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('steigenberger_tahrir_cairo', 'Steigenberger Hotel El Tahrir', 'Steigenberger Hotel El Tahrir', 'فندق شتايجنبرجر التحرير', 'A contemporary hotel on Tahrir Square, steps from the Egyptian Museum and central Downtown Cairo.', 'A contemporary hotel on Tahrir Square, steps from the Egyptian Museum and central Downtown Cairo.', 'فندق عصري في ميدان التحرير، على بُعد خطوات من المتحف المصري ووسط القاهرة.', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.5, 'Hotels', 'فنادق', 30.0468, 31.2351, '2 Kasr El Nile Street, Tahrir Square', '٢ شارع قصر النيل، ميدان التحرير', 'Open 24 hours', 5200, 'expensive', 'Rates vary by date and room', 5000, 5000, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('kempinski_nile_garden_city', 'Kempinski Nile Hotel Garden City', 'Kempinski Nile Hotel Garden City', 'فندق كمبينسكي النيل جاردن سيتي', 'A luxury boutique hotel on the Nile in Garden City, with easy access to Downtown Cairo and the riverfront.', 'A luxury boutique hotel on the Nile in Garden City, with easy access to Downtown Cairo and the riverfront.', 'فندق بوتيكي فاخر على النيل في جاردن سيتي، يتيح الوصول بسهولة إلى وسط القاهرة والكورنيش.', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.6, 'Hotels', 'فنادق', 30.0369, 31.2307, '12 Ahmed Ragheb Street, Garden City', '١٢ شارع أحمد راغب، جاردن سيتي', 'Open 24 hours', 4700, 'expensive', 'Rates vary by date and room', 9000, 9000, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('four_seasons_nile_plaza', 'Four Seasons Hotel Cairo at Nile Plaza', 'Four Seasons Hotel Cairo at Nile Plaza', 'فندق فورسيزونز نايل بلازا جاردن سيتي', 'A luxury Nile-front hotel in Garden City overlooking the river and close to Cairo’s central cultural district.', 'A luxury Nile-front hotel in Garden City overlooking the river and close to Cairo’s central cultural district.', 'فندق فاخر على واجهة النيل في جاردن سيتي، يطل على النهر ويقع بالقرب من المنطقة الثقافية المركزية بالقاهرة.', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.8, 'Hotels', 'فنادق', 30.0357, 31.2296, '1089 Corniche El Nil, Garden City', '١٠٨٩ كورنيش النيل، جاردن سيتي', 'Open 24 hours', 7200, 'expensive', 'Rates vary by date and room', 15000, 15000, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('waldorf_astoria_heliopolis', 'Waldorf Astoria Cairo Heliopolis', 'Waldorf Astoria Cairo Heliopolis', 'فندق والدورف أستوريا مصر الجديدة', 'A luxury hotel in Heliopolis near Cairo International Airport, offering a convenient base for the eastern side of the city.', 'A luxury hotel in Heliopolis near Cairo International Airport, offering a convenient base for the eastern side of the city.', 'فندق فاخر في مصر الجديدة بالقرب من مطار القاهرة الدولي، ويوفر موقعاً مناسباً لاستكشاف شرق المدينة.', 'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.7, 'Hotels', 'فنادق', 30.103, 31.365, 'Orouba Street, Heliopolis, Cairo', 'شارع العروبة، مصر الجديدة، القاهرة', 'Open 24 hours', 1900, 'expensive', 'Rates vary by date and room', 11000, 11000, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_nbe_tahrir', 'NBE ATM - Tahrir Square', 'NBE ATM - Tahrir Square', 'ماكينة صراف البنك الأهلي المصري - ميدان التحرير', 'A National Bank of Egypt cash machine serving visitors around Tahrir Square and the Egyptian Museum.', 'A National Bank of Egypt cash machine serving visitors around Tahrir Square and the Egyptian Museum.', 'ماكينة صراف آلي تابعة للبنك الأهلي المصري لخدمة زوار ميدان التحرير والمتحف المصري.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0446, 31.2355, 'Tahrir Square, Downtown Cairo', 'ميدان التحرير، وسط القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_cib_zamalek', 'CIB ATM - 26th of July St, Zamalek', 'CIB ATM - 26th of July St, Zamalek', 'ماكينة صراف CIB - شارع 26 يوليو الزمالك', 'A Commercial International Bank ATM on 26th of July Street in Zamalek, convenient for visitors on Gezira Island.', 'A Commercial International Bank ATM on 26th of July Street in Zamalek, convenient for visitors on Gezira Island.', 'ماكينة صراف للبنك التجاري الدولي في شارع ٢٦ يوليو بالزمالك، مناسبة لزوار جزيرة الجزيرة.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0578, 31.2212, '26th of July Street, Zamalek', 'شارع ٢٦ يوليو، الزمالك', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_bm_hussein_khan', 'Banque Misr ATM - Al-Hussein / Khan El-Khalili', 'Banque Misr ATM - Al-Hussein / Khan El-Khalili', 'ماكينة صراف بنك مصر - الحسين وخان الخليلي', 'A Banque Misr cash machine serving the Al-Hussein district and Khan El-Khalili heritage market.', 'A Banque Misr cash machine serving the Al-Hussein district and Khan El-Khalili heritage market.', 'ماكينة صراف آلي لبنك مصر تخدم منطقة الحسين وسوق خان الخليلي التراثي.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0479, 31.2634, 'Al-Hussein, Al-Gamaliya, Cairo', 'الحسين، الجمالية، القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_nbe_korba', 'NBE ATM - Al-Korba, Heliopolis', 'NBE ATM - Al-Korba, Heliopolis', 'ماكينة صراف البنك الأهلي المصري - الكوربة مصر الجديدة', 'A National Bank of Egypt ATM in Al-Korba, serving the Heliopolis shopping and heritage district.', 'A National Bank of Egypt ATM in Al-Korba, serving the Heliopolis shopping and heritage district.', 'ماكينة صراف آلي تابعة للبنك الأهلي المصري في الكوربة لخدمة منطقة التسوق والتراث بمصر الجديدة.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0906, 31.3251, 'Al-Korba, Heliopolis, Cairo', 'الكوربة، مصر الجديدة، القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_cib_talaat_harb', 'CIB ATM - Talaat Harb St, Downtown', 'CIB ATM - Talaat Harb St, Downtown', 'ماكينة صراف CIB - طلعت حرب وسط البلد', 'A Commercial International Bank ATM in Downtown Cairo near Talaat Harb Street and Tahrir Square.', 'A Commercial International Bank ATM in Downtown Cairo near Talaat Harb Street and Tahrir Square.', 'ماكينة صراف للبنك التجاري الدولي في وسط القاهرة بالقرب من شارع طلعت حرب وميدان التحرير.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0474, 31.2393, 'Talaat Harb Street, Downtown Cairo', 'شارع طلعت حرب، وسط القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_nbe_citadel', 'NBE ATM - Citadel Square', 'NBE ATM - Citadel Square', 'ماكينة صراف البنك الأهلي المصري - ميدان القلعة', 'A National Bank of Egypt ATM near Citadel Square, serving visitors to the Citadel and Sultan Hassan Mosque.', 'A National Bank of Egypt ATM near Citadel Square, serving visitors to the Citadel and Sultan Hassan Mosque.', 'ماكينة صراف آلي تابعة للبنك الأهلي المصري بالقرب من ميدان القلعة لخدمة زوار القلعة ومسجد السلطان حسن.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.031, 31.2552, 'Citadel Square, Cairo', 'ميدان القلعة، القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_bm_mar_girgis', 'Banque Misr ATM - Mar Girgis / Coptic Cairo', 'Banque Misr ATM - Mar Girgis / Coptic Cairo', 'ماكينة صراف بنك مصر - مجمع الأديان مصر القديمة', 'A Banque Misr ATM near Mar Girgis metro station and the Coptic Cairo religious heritage district.', 'A Banque Misr ATM near Mar Girgis metro station and the Coptic Cairo religious heritage district.', 'ماكينة صراف لبنك مصر بالقرب من محطة مترو مار جرجس ومنطقة مجمع الأديان في القاهرة القبطية.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0065, 31.2295, 'Mar Girgis, Old Cairo', 'مار جرجس، مصر القديمة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_cib_maadi_road9', 'CIB ATM - Road 9, Maadi', 'CIB ATM - Road 9, Maadi', 'ماكينة صراف CIB - شارع 9 المعادي', 'A Commercial International Bank ATM on Road 9, a central visitor and shopping street in Maadi.', 'A Commercial International Bank ATM on Road 9, a central visitor and shopping street in Maadi.', 'ماكينة صراف للبنك التجاري الدولي في شارع ٩، أحد الشوارع الرئيسية للتسوق وزيارة المعادي.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 29.9598, 31.2582, 'Road 9, Maadi, Cairo', 'شارع ٩، المعادي، القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_qnb_garden_city', 'QNB ATM - Garden City', 'QNB ATM - Garden City', 'ماكينة صراف QNB - جاردن سيتي', 'A QNB cash machine in Garden City, close to the Nile Corniche and central Cairo hotels.', 'A QNB cash machine in Garden City, close to the Nile Corniche and central Cairo hotels.', 'ماكينة صراف آلي تابعة لبنك QNB في جاردن سيتي بالقرب من كورنيش النيل وفنادق وسط القاهرة.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0378, 31.2338, 'Garden City, Cairo', 'جاردن سيتي، القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo'),
  ('atm_nbe_abdeen', 'NBE ATM - Abdeen Square', 'NBE ATM - Abdeen Square', 'ماكينة صراف البنك الأهلي المصري - ميدان عابدين', 'A National Bank of Egypt cash machine near Abdeen Square and the Abdeen Palace Museum in Downtown Cairo.', 'A National Bank of Egypt cash machine near Abdeen Square and the Abdeen Palace Museum in Downtown Cairo.', 'ماكينة صراف آلي تابعة للبنك الأهلي المصري بالقرب من ميدان عابدين ومتحف قصر عابدين في وسط القاهرة.', 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=1200&q=85', ARRAY[]::text[], 4.0, 'ATM', 'صراف آلي', 30.0434, 31.2464, 'Abdeen Square, Downtown Cairo', 'ميدان عابدين، وسط القاهرة', 'Open 24 hours', 0, 'free', 'Bank fees and limits may apply', NULL, NULL, FALSE, FALSE, 999, TRUE, TRUE, 'cairo')
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_en = EXCLUDED.name_en,
  name_ar = EXCLUDED.name_ar,
  description = EXCLUDED.description,
  description_en = EXCLUDED.description_en,
  description_ar = EXCLUDED.description_ar,
  image_url = EXCLUDED.image_url,
  image_urls = EXCLUDED.image_urls,
  rating = EXCLUDED.rating,
  category = EXCLUDED.category,
  category_ar = EXCLUDED.category_ar,
  lat = EXCLUDED.lat,
  lng = EXCLUDED.lng,
  address = EXCLUDED.address,
  address_ar = EXCLUDED.address_ar,
  open_hours = EXCLUDED.open_hours,
  review_count = EXCLUDED.review_count,
  price_level = EXCLUDED.price_level,
  price_note = EXCLUDED.price_note,
  price_local_egp = EXCLUDED.price_local_egp,
  price_foreigner_egp = EXCLUDED.price_foreigner_egp,
  is_hidden_gem = EXCLUDED.is_hidden_gem,
  is_featured = EXCLUDED.is_featured,
  display_order = EXCLUDED.display_order,
  enable_chat = EXCLUDED.enable_chat,
  enable_gallery = EXCLUDED.enable_gallery,
  governorate = EXCLUDED.governorate;

INSERT INTO public.tours (
  id, title, title_ar, description, description_ar, duration, duration_ar, category, category_ar, image_url, status, is_premium, is_hidden_gem, governorate
)
VALUES
  ('cairo_islamic_fatimid_walk', 'Fatimid Cairo & Al-Muizz Heritage Walk', 'جولة القاهرة الفاطمية وخان الخليلي', 'Walk the historic lanes of Islamic Cairo, tracing Fatimid and Mamluk landmarks from Al-Muizz Street through Khan El-Khalili and Al-Azhar.', 'جولة سير في أزقة القاهرة الإسلامية بين معالم العصرين الفاطمي والمملوكي، من شارع المعز إلى خان الخليلي والجامع الأزهر وحديقة الأزهر.', '4 hours', '٤ ساعات', 'Heritage', 'تراث', 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=85', 'published', FALSE, FALSE, 'cairo'),
  ('cairo_citadel_fustat_trail', 'Citadel, Coptic Cairo & NMEC Trail', 'مسار القلعة ومجمع الأديان والفسطاط', 'Connect the Citadel and Sultan Hassan Mosque with Coptic Cairo and the NMEC in Fustat for a day spanning Cairo’s medieval and ancient heritage.', 'مسار يربط قلعة صلاح الدين ومسجد السلطان حسن بالقاهرة القبطية ومتحف الحضارة في الفسطاط، في رحلة عبر تراث القاهرة الوسيط والقديم.', 'Full day', 'يوم كامل', 'Heritage', 'تراث', 'https://images.unsplash.com/photo-1568322445389-f64ac2515020?auto=format&fit=crop&w=1200&q=85', 'published', FALSE, FALSE, 'cairo')
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  title_ar = EXCLUDED.title_ar,
  description = EXCLUDED.description,
  description_ar = EXCLUDED.description_ar,
  duration = EXCLUDED.duration,
  duration_ar = EXCLUDED.duration_ar,
  category = EXCLUDED.category,
  category_ar = EXCLUDED.category_ar,
  image_url = EXCLUDED.image_url,
  status = EXCLUDED.status,
  is_premium = EXCLUDED.is_premium,
  is_hidden_gem = EXCLUDED.is_hidden_gem,
  governorate = EXCLUDED.governorate;

DELETE FROM public.tour_places
WHERE tour_id IN ('cairo_islamic_fatimid_walk', 'cairo_citadel_fustat_trail');
INSERT INTO public.tour_places (tour_id, place_id, position)
VALUES
  ('cairo_islamic_fatimid_walk', 'al_muizz_street', 0),
  ('cairo_islamic_fatimid_walk', 'khan_el_khalili', 1),
  ('cairo_islamic_fatimid_walk', 'al_azhar_mosque', 2),
  ('cairo_islamic_fatimid_walk', 'al_azhar_park', 3),
  ('cairo_citadel_fustat_trail', 'cairo_citadel', 0),
  ('cairo_citadel_fustat_trail', 'sultan_hassan_mosque', 1),
  ('cairo_citadel_fustat_trail', 'hanging_church', 2),
  ('cairo_citadel_fustat_trail', 'coptic_museum', 3),
  ('cairo_citadel_fustat_trail', 'nmec_fustat', 4)
ON CONFLICT (tour_id, place_id) DO UPDATE
SET position = EXCLUDED.position;

CREATE OR REPLACE VIEW public.tours_with_places AS
SELECT
  t.id,
  t.title,
  t.title_ar,
  t.description,
  t.description_ar,
  t.duration,
  t.duration_ar,
  t.category,
  t.category_ar,
  t.image_url,
  t.created_at,
  t.updated_at,
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'id', p.id,
          'name', p.name,
          'name_ar', p.name_ar,
          'description', p.description,
          'description_ar', p.description_ar,
          'image_url', p.image_url,
          'imageUrl', p.image_url,
          'image_urls', p.image_urls,
          'rating', p.rating,
          'category', p.category,
          'category_ar', p.category_ar,
          'lat', p.lat,
          'lng', p.lng,
          'address', p.address,
          'address_ar', p.address_ar,
          'open_hours', p.open_hours,
          'openHours', p.open_hours,
          'review_count', p.review_count,
          'reviewCount', p.review_count,
          'price_level', p.price_level,
          'priceLevel', p.price_level,
          'price_note', p.price_note,
          'priceNote', p.price_note,
          'price_local_egp', p.price_local_egp,
          'priceLocalEgp', p.price_local_egp,
          'price_foreigner_egp', p.price_foreigner_egp,
          'priceForeignerEgp', p.price_foreigner_egp,
          'is_hidden_gem', p.is_hidden_gem,
          'isHiddenGem', p.is_hidden_gem,
          'is_featured', p.is_featured,
          'governorate', p.governorate,
          'display_order', p.display_order,
          'enable_chat', p.enable_chat,
          'enable_gallery', p.enable_gallery
        )
        ORDER BY tp.position
      )
      FROM public.tour_places tp
      JOIN public.places p ON p.id = tp.place_id
      WHERE tp.tour_id = t.id
    ),
    '[]'::json
  ) AS places,
  t.status,
  t.view_count,
  t.is_premium,
  t.is_hidden_gem,
  t.governorate
FROM public.tours t;

COMMIT;

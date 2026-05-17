-- Scoped GEDCOM notes import for Apno Ki Talash.
-- Run in AKT Supabase project: https://fusairoeiabmqvsbxhfi.supabase.co
-- Generated from /Users/shiraz/Downloads/202-Shiraz-familyof-Rasra.ged.
-- This imports existing notes only for the latest upload of 202-Shiraz-familyof-Rasra.ged.

ALTER TABLE public.people ADD COLUMN IF NOT EXISTS notes TEXT;

UPDATE public.people
SET notes = 'Khalajad bhai from another khala'
WHERE raw_gedcom_id = '@I2786@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Blue Star Finishers<br>Mobile - 9415051970'
WHERE raw_gedcom_id = '@I2288@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'His wife was Ghazala Chachi ki real phuppi ...'
WHERE raw_gedcom_id = '@I425@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'She was married to someone in Biradari, but later got divorced and remarried tosomeone outside the biradari.'
WHERE raw_gedcom_id = '@I3040@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Birth time - Thursday, 11 AM'
WHERE raw_gedcom_id = '@I123@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Died in 7 years age'
WHERE raw_gedcom_id = '@I950@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '(below is as narrated by my father Dr Anwar Ahmad)<br>--<br>He was IAS from thefirst batch when ICS Exams were terminated. His whereabout is unknown, last known thing about him was that he took a train to Pakistan along with his few other fellow officers. Later it was assumed that he was killed by rioters along with many other IAS officers who were traveling with him in the same train. He didn''t has any marriage or a family.'
WHERE raw_gedcom_id = '@I419@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- Page 33; Apnon ki Talaash'
WHERE raw_gedcom_id = '@I1190@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Mr Ayyub lives near Habeeba mosque in Kanpur'
WHERE raw_gedcom_id = '@I3290@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- > Hazra Bibi and Deputy Basheer were cousins. <br> - > Hazra Bibi was the daughter of Deputy Basheer''s Phuphi - Maryam Bibi.<br> - > Deputy Basheer was son of Hazra Bibi''s Mamu Sheikh Amzad Ali.<br> - > That way, Deputy Basheer''s kids (ICS Manzoor Alam and others) were direct nephew (bhanje) of Hakeem Zakariya; and therefore first cousin brothers of Dr Obaidullah and others. <br> - > Although, they were second cousins from the older relations.'
WHERE raw_gedcom_id = '@I413@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Qais sb is a sr person (dada level) at Royal Dental next to Dawat guest house in Defence colony.'
WHERE raw_gedcom_id = '@I3073@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'He died in early age without any marriage or Children.'
WHERE raw_gedcom_id = '@I562@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'https://timesofindia.indiatimes.com/city/kanpur/fire-engulfs-4-storey-building-in-ups-chamanganj-several-residents-trapped/articleshow/120884224.cms'
WHERE raw_gedcom_id = '@I3056@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Haleem Market, Chamanganj, Kanpur<br>9839503506'
WHERE raw_gedcom_id = '@I1913@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Pitney Bowes'
WHERE raw_gedcom_id = '@I2568@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Lola Bhai'
WHERE raw_gedcom_id = '@I1351@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'She is a Gynae and working in UK, London.'
WHERE raw_gedcom_id = '@I3093@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Daughter of Parvez,<br>Grand daughter of Haji Mubeen of Merchant Chamber Tannery.'
WHERE raw_gedcom_id = '@I3082@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- This family was migrated to Bangladesh and later was killed in riots.'
WHERE raw_gedcom_id = '@I1280@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'khalajad bhai, but divorced.'
WHERE raw_gedcom_id = '@I2785@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '(Sadiya International)'
WHERE raw_gedcom_id = '@I1744@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'never married.'
WHERE raw_gedcom_id = '@I626@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- He was the eldest son from the second marriage. <br> - He migrated to Pakistan, though returned to India and died here but his family remained in Pakistan. <br> - We still need to find and figure out his family roots further down the line.'
WHERE raw_gedcom_id = '@I564@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'She is currently employed with Intel, and stays in Portland, USA with her ENT surgeon husband.'
WHERE raw_gedcom_id = '@I3097@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Approximately during this time they switched to Zamindari from the business of Indigo exports. They experienced a major setback when two ships exporting Indigo sank in the ocean. As per stories they had their registered export offices present in Kanpur Kolkata Allahabad and Benaras.<br><br>His other famous work was completing the structure of Kothi in Rasra, Mosque associated with Kothi'
WHERE raw_gedcom_id = '@I405@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Suhagan Bibi was the second wife of Moulvi Mohammad Ali; First wife had only two wards, not sure about the reason of 2nd marriage.'
WHERE raw_gedcom_id = '@I514@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'She has an interesting case:<br><br> - She was married first to Hafiz Ahmad Alias her 2nd wife;<br> - Hafiz Ahmad Ali died during his Haj journey (1905 yr) and was buried at Jannat-ul-baqi;<br> - Later on, she gave birth to Haji Zameer Ahmad posthumously.<br> - She was married to Hafiz Ahmad Ali''s brother Sheikh Amzad Ali (again as his 2nd wife); with this wedlock, she had a daugter Khairun Nesa who was then married to Md Ilyas of Rasra.<br><br>** Seems like, due to plague many people died untimely, and in this situation such arrangements were done.'
WHERE raw_gedcom_id = '@I398@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Grandson (Naati) of KhairunNesa daadee, <br>KhairunNesa daadee was a sibling ofmy Dadi NoorunNesa.'
WHERE raw_gedcom_id = '@I2373@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Stays in DALLAS IN USA.'
WHERE raw_gedcom_id = '@I3080@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'He was in Australia.<br>Currently, fighting with Cancer. <br>A friend of Shuza Moazzam'
WHERE raw_gedcom_id = '@I2989@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'His wife is an Oriya, Hindu girl - converted to Islam. Name unknown.'
WHERE raw_gedcom_id = '@I3118@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Nawa Nagar - Jama Masjid built in Yr 1831'
WHERE raw_gedcom_id = '@I1304@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Biographical Note<br><br>Birthplace: Rasra, Ballia<br>Education: BHMS, Allahabad University<br><br>Life Summary<br><br>Born in Rasra, Ballia, he pursued medical studies and completed his BHMS from Allahabad University, dedicating himself to a life of healing and service through homeopathy.<br><br>He began his professional journey by establishing a homeopathy practice in his hometown of Rasra, quickly earning the trust and respect of the community for his heartfelt care and sincerity.<br><br>On 5 November 1969, he married Firdaus Shahina, daughter of Advocate Rafique Ahmad Lari, in Lar—marking the beginning of a nurturing and dignified family life.<br><br>In the early 1980s, he moved to Kanpur, where he co-founded Navratan Tannery in Jajmau (around 1979) with his brothers Maqbool and Akhtar.<br><br>The name “Navratan” itself was a tribute inspired by his nine real brothers, symbolizing unity, strength, and the collective identity of the family.<br><br>The tannery flourished for years and was eventually sold in the late 1990s to his brother-in-law, Ashfaque sb, closing a significant entrepreneurial chapter in the family’s journey.<br><br>A long-term diabetic, he eventually succumbed to Chronic Kidney Disease (Stage 5) and passed away peacefully in June 2020 at the age of 78, leaving behind a legacy of humility, hard work, compassion, and quiet resilience.'
WHERE raw_gedcom_id = '@I6@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '15th child; 9th brother in the order of sons;<br>Birth time = 5AM, Wednesday;'
WHERE raw_gedcom_id = '@I137@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '12th children, 7th in the order of Sons.<br>Birth time - 4pm, Tuesday'
WHERE raw_gedcom_id = '@I129@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '10th child of Haji Zameer Ahmad (considering everyone)<br>Birth time - 4:30 AM,Wednesday<br>Correct date of death need to find out, approximately - it was yr 2011.<br>Sudden death due to reaction of some medicine - exact reason is not known to me.'
WHERE raw_gedcom_id = '@I125@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- Late Haji Zamir Ahmad sb was actually born in 1906 but his official year of birth is 1908. <br><br> - His father Janab Ahmed Ali sb went to Hajj in December 1905, and Zamir sb  was born  posthumously.<br><br> - He died on 07.11.1974'
WHERE raw_gedcom_id = '@I33@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Birth on Monday 2 PM <br>Death on 7:50PM in Lucknow.'
WHERE raw_gedcom_id = '@I120@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Business - <br>Ocean Leather<br>192/194, Ram Rai Sarai, <br>Jajmau, Kanpur<br><br>Home - <br>Plot No 193, Phase2, Emerald Gulistan,<br>Jajmau, Kanpur<br>9696947967<br>7499516512'
WHERE raw_gedcom_id = '@I624@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Birth Time - Thursday, 11 AM<br>Death - 10 Jan 2019<br>Married to -> Ekramunnesa, Daughter of Abdul Majeed, Baluwa - Feb 4th, 1959'
WHERE raw_gedcom_id = '@I118@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Birth time= Tuesday, 10AM'
WHERE raw_gedcom_id = '@I134@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'They used to live in Chamanganj Kanpur, now in Shitla Bazaar - Ashrafabad'
WHERE raw_gedcom_id = '@I59@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Shaheen is from outside biradari, converted.'
WHERE raw_gedcom_id = '@I384@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Munnu Mamani ki khala ke ladke hain yeh'
WHERE raw_gedcom_id = '@I1473@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'ICS of last batch... -- as narrated by my Father Dr. Anwar Ahmad'
WHERE raw_gedcom_id = '@I418@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'S/o Zaibunnesa.<br>Zaibunnesa was the khala of Hoorlaka.<br>Sister of Mahelaka the w/o Zaheer Choudhary.'
WHERE raw_gedcom_id = '@I3266@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Apnon ki talash me page no 32 dekhiye'
WHERE raw_gedcom_id = '@I531@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- First Wife = Muqima Bibi<br> - Second Wife = Zaibun Nesa (she had two marriages, First Husband Hafiz Ahmad Ali F/O Haji Zameer Ahmad, second husband Sheikh Amzad Ali)'
WHERE raw_gedcom_id = '@I408@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Apnon ki Talash - page no 32, Shijra 21(2)(1)'
WHERE raw_gedcom_id = '@I912@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Divorced.'
WHERE raw_gedcom_id = '@I1574@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Computer Engineering Graduation<br>Settled in Atlanta, USA since yr 2000.<br>Currently a USA citizen.'
WHERE raw_gedcom_id = '@I19@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Currently settled in Bahrain since year 2007.<br>Mechanical Engineer from AMU pass out in year 2002.'
WHERE raw_gedcom_id = '@I8@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Mohammad Shiraz Anwar is a seasoned Product & Program Leadership executive who has spent over two decades driving high-velocity execution across global technology organizations, including Adobe, MakeMyTrip, Paytm, SWOO, and now TeleCRM. Known for transforming chaotic, multi-stream work into disciplined, data-driven delivery systems, he brings a rare combination of strategic product thinking and operational excellence.<br><br>A certified ScrumMaster (CSM) and recognized Generative AI Leader, Shiraz blends modern product practices with AI-driven execution intelligence to build scalable, predictable operating models. His leadership consistently delivers clarity, alignment, and speed across cross-functional teams spanning Product, Engineering, Design, Data, and Operations.<br><br>As a former entrepreneur who built and led a real-time digital signage startup (meraAdBoard), he pairs deep execution discipline with business pragmatism—enabling organizations to move fast without losing control. He is widely regarded for his ability to architect lightweight frameworks, delivery playbooks, and governance rhythms that empower teams with autonomy while maintaining execution precision.<br><br>Passionate about AI-enabled transformation, process scalability, and high-accountability cultures, Shiraz brings the vision of a product thinker, the rigor of a program leader, and the mindset of a founder—making him a force multiplier in complex, high-growth environments.'
WHERE raw_gedcom_id = '@I1@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '13th Child in the order of everyone;<br>Birth time = 10AM, Thursday;'
WHERE raw_gedcom_id = '@I132@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'twin with his sister'
WHERE raw_gedcom_id = '@I1347@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Twin with her brother'
WHERE raw_gedcom_id = '@I1348@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Sumaiya''s mother is not from any of the House of Biradari.'
WHERE raw_gedcom_id = '@I395@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '1. Known by everyone as wakeelain chachi; and her bhabhi as diptiyain chachi;<br>2. Other than Ashfaq, she had 3 more brothers including a name Sajjad, we guess all died in Bangladesh.'
WHERE raw_gedcom_id = '@I1457@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Mannan bhaiya was re-married to the wife of Wahab bhaiya after his death. <br>She has already two children Javed and Parvez from Wahab bhaiya. Later on she had more children after this wedlock with Mannan bhaiya.'
WHERE raw_gedcom_id = '@I2990@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'One of the grand daughter of Halima Bibi, named Umm-e-Nabiun (daughter via Son Aleem Ahmad) was married to her nephew Hafiz Zaheer Ahmad who was son of Sheikh Amzad Ali.<br><br>So basically, Hafiz Zaheer was uncle of his wife via original relation. <br>Hafiz Zaheer got married to his phuphi''s grand-daughter.<br><br>Halima Bibi was one of the sisters of Moulwi Mohd Ali, Hafiz Ahmad Ali (our great grand father) and Sheikh Amzad Ali.'
WHERE raw_gedcom_id = '@I529@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- One of her son was married to the daughter of Muneer waqeel.'
WHERE raw_gedcom_id = '@I401@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Her Family leads to Dr Obaidullah (their kids are in KDA, next to Green Garden)'
WHERE raw_gedcom_id = '@I518@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Not sure about the existence of NoorunNesa and Khairunnesa as daughters of Nabuwwat bibi, keeping it some time till I go back and check my sources.<br><br>Kamran bhai confirmed about Abul Hasan ICS and Oona bibi. Attaching the proof as well.'
WHERE raw_gedcom_id = '@I516@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Married to a Hindu Agrawal (Baniya caste)'
WHERE raw_gedcom_id = '@I3122@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Girl is from outside Iraqi biardari.'
WHERE raw_gedcom_id = '@I209@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Mamu of Zaheer Choudhary.<br>Brother of Kulsum.<br>Kulsum was married to Md Nabi - and has Daughter NoorunNesa, and son Zaheer Choudhary<br>Kulsum was remarried to someone else - and has Amzad Mamu as a son.'
WHERE raw_gedcom_id = '@I3037@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Died early after the marriage and after having two little kids, in an air crashnear Nepal.'
WHERE raw_gedcom_id = '@I1575@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'One of the oldest and finest principle of Lar based OKM Inter College.<br>Used to check students are studying in night; when Ammi ke chhote abba were high school students.'
WHERE raw_gedcom_id = '@I1225@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Eid-ul-fitr day when she died.<br>No children.<br>Raised Munna phuphi with her in Kolkata.'
WHERE raw_gedcom_id = '@I107@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Resident of Forbisganj, Bihar'
WHERE raw_gedcom_id = '@I122@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Her husband was killed in an air crash accident near Nepal ... back in mid 90s sometime ...'
WHERE raw_gedcom_id = '@I1386@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Girl is from outside Iraqi biradari.'
WHERE raw_gedcom_id = '@I208@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'from first wife'
WHERE raw_gedcom_id = '@I2940@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Getting settled in Emerald Gulistan'
WHERE raw_gedcom_id = '@I576@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Birth time = 8PM, Friday;<br>Starting 10 yrs was passed in her Nani''s house before she came to her own home;'
WHERE raw_gedcom_id = '@I140@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Time - 5PM, Saturday'
WHERE raw_gedcom_id = '@I307@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'This is a marriage between cousin brother and sisters. <br>Mother in law (Khatoon Jannat) of Sajida Khatoon was her real phuphi as well.'
WHERE raw_gedcom_id = '@I902@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'S/o Dildar Sb Kolkata'
WHERE raw_gedcom_id = '@I3135@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Haleem Market, Kanpur'
WHERE raw_gedcom_id = '@I580@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Died recently on 7th March 2025'
WHERE raw_gedcom_id = '@I104@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- >> Zaina and Maaz were born as twins'
WHERE raw_gedcom_id = '@I622@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Zaina and Maaz were born as twins'
WHERE raw_gedcom_id = '@I623@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'At this point -- <br>From Sheikh Raheemullah -- Chandii family of Abdur Rahman come into existence; convergence point from my Nani''s father''s family or you could say Asif/Qasim Mamu''s family.<br><br>From Sheikh Kareemullah -- it would ultimately point down to Sarwat Sb, Dilshad Sb, Fathers families. but this is the convergence point for both families.'
WHERE raw_gedcom_id = '@I1645@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'page no 85; apno ki talash'
WHERE raw_gedcom_id = '@I926@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Death in Chennai, during a bypass surgery in the Apollo Hospital.'
WHERE raw_gedcom_id = '@I119@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Nanee of Zafar Phupha (husband of Farhana phuppi of Shamama Appi)'
WHERE raw_gedcom_id = '@I2318@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Ummat un Nesa is also a phuppi of Dilshad sb (my father in law)'
WHERE raw_gedcom_id = '@I1375@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'He also stays in DALLAS, USA with his uncle Arshad Neyaz. Shifted there after the graduation from India.'
WHERE raw_gedcom_id = '@I3089@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'No further details are available about this family.'
WHERE raw_gedcom_id = '@I517@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'status = divorced'
WHERE raw_gedcom_id = '@I987@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'just married in Feb 2024'
WHERE raw_gedcom_id = '@I1042@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'He was son of Mohd Yunus Marhoom... famously known as Yunus Charbeewala in Kolkata. Resident of 17No Damzen Lane - Ashfaq phuppa.'
WHERE raw_gedcom_id = '@I1383@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Not part of Iraqi biradri; based out of Australia.'
WHERE raw_gedcom_id = '@I204@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Ramzaan Ali is the father of Sheikh Abdus Samad who donated half his property to  a mosque in Rasra and is registered as wakf no 2 and another mosque is at waqf no 3<br>He seems to be migrated to Pakistan with his son during partition.'
WHERE raw_gedcom_id = '@I2977@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Qadri Sherwani'
WHERE raw_gedcom_id = '@I360@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- Falak Zafar is the daughter of her own mother-in-law''s brother (Tanveer Zafar); i.e. Fazeel''s Mamu''s (Tanveer Zafar) daughter. <br><br> - Shamaila Zafar is Falak''s own phuphi.'
WHERE raw_gedcom_id = '@I392@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = '- Ujala (Shamaila Zafar) and Zulekha Zafar (Gudia) are real sisters; that makesShadab Anwar (USA) and Naiyer Maqbool sadhu bhai of each other.<br><br> - Another notable sadhu bhai of Shadab and Naiyer Maqbool is Haji Parvez of Indian Tannery via Sweety aka Faryal ZAfar.'
WHERE raw_gedcom_id = '@I390@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Outside IB'
WHERE raw_gedcom_id = '@I1445@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Married to Khalajad bhai'
WHERE raw_gedcom_id = '@I2772@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

UPDATE public.people
SET notes = 'Twin with Danyal'
WHERE raw_gedcom_id = '@I1014@'
  AND gedcom_id = (
    SELECT id
    FROM public.gedcom_uploads
    WHERE filename = '202-Shiraz-familyof-Rasra.ged'
    ORDER BY uploaded_at DESC
    LIMIT 1
  );

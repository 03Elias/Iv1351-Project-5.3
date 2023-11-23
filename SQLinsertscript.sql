--iv1351 insertion script-- Participants: Elias Gaghlasian, Leo Långberg, Ammar Alzeno CINTE Year 2

--insert all people into person 
INSERT INTO person (name, contact_details_tlf, personal_number, address)
VALUES
  ('stud1','070-312-21-43', 20021002, 'studhome 0'),
  ('stud2','070-312-21-44', 20041004,'studhome 0'),
  ('instruc1','070-312-21-46', 20021006, 'Adminstreet 1'),
  ('studparent','070-312-21-47', 19740202, 'studhome 0');



--to retrieve id
CREATE VIEW stud1 	AS( SELECT person_id FROM person WHERE name = 'stud1' LIMIT 1);
CREATE VIEW stud2 	AS( SELECT person_id FROM person WHERE name = 'stud2' LIMIT 1);
CREATE VIEW instruc1 AS (SELECT person_id FROM person WHERE name = 'instruc1' LIMIT 1);

--brand stud1 & stud2 as students
INSERT INTO student(student_id)
VALUES((SELECT person_id FROM stud1)),
	  ((SELECT person_id FROM stud2));

			--Make stud1 & stud2 are siblings
			--Trigger will make it symmetrical
			INSERT INTO student_sibling(student_id, sibling_id)
			VALUES((SELECT person_id FROM stud1), (SELECT person_id FROM stud2));

			INSERT INTO student_contact_person(student_id, contact_person_id)
			VALUES((SELECT person_id FROM stud1), (SELECT person_id FROM person WHERE name = 'studparent')),
				   ((SELECT person_id FROM stud2), (SELECT person_id FROM person WHERE name = 'studparent'));

--brand instruc1 as instructor
INSERT INTO instructor(instructor_id)
VALUES ((SELECT person_id FROM instruc1));

			--store available time for instructor
			INSERT INTO instructor_time_available( instructor_id, time_available)
			VALUES ((SELECT person_id FROM instruc1), '2023-12-01 08:00:00');

--create instruments in the database
INSERT INTO instrument( instrument_type_name )
VALUES('Piano'),
		('Violin'),
		('Bass');
			CREATE VIEW instrument1 AS(SELECT instrument_id FROM instrument WHERE instrument_type_name = 'Piano' LIMIT 1);
			---insert stock of physical instruments
			INSERT INTO in_stock(instrument_id, brand, cost)
			VALUES((SELECT instrument_id FROM instrument1),'Steinway', 50.00);

			--rent the physical instrument
			INSERT INTO instrument_rental(time_rented, student_id, rental_id)
			VALUES(CURRENT_DATE, (SELECT person_id FROM stud1), 
				(SELECT rental_id FROM in_stock WHERE instrument_id = (SELECT instrument_id FROM instrument1)));


--insert lessons into database
--insert lessons into database
INSERT INTO lesson(min_students, max_students, lesson_time, instructor_id)
VALUES
  (2, 5, '2023-12-01 09:00:00', (SELECT person_id FROM instruc1)),
  (2, 7, '2023-12-01 10:00:00', (SELECT person_id FROM instruc1)),
  (NULL, NULL, '2023-12-01 08:00:00', (SELECT person_id FROM instruc1)); 
	--will be automatically set by trigger

			--specialize the lessons
			CREATE VIEW groupl   AS( SELECT lesson_id FROM lesson WHERE lesson_time = '2023-12-01 09:00:00' LIMIT 1);
			CREATE VIEW ensambl  AS(SELECT lesson_id FROM lesson WHERE lesson_time = '2023-12-01 10:00:00' LIMIT 1);
			CREATE VIEW individl AS(SELECT lesson_id FROM lesson WHERE lesson_time = '2023-12-01 08:00:00' LIMIT 1);

			INSERT INTO grouplesson(lesson_id, level, instrument_id)
			VALUES((SELECT lesson_id FROM groupl), 'Beginner', (SELECT instrument_id FROM instrument1));

			INSERT INTO ensamble(lesson_id, genres)
			VALUES((SELECT lesson_id FROM ensambl), 'Jazz');

			INSERT INTO individual(lesson_id, level, instrument_id)
			VALUES((SELECT lesson_id FROM individl), 'Advanced', (SELECT instrument_id FROM instrument1));
			--Trigger will make sure that lesson_time for individual exists in instructor_time_available.

--insert students into lessons (student_count updated on Trigger)
INSERT INTO student_lesson_cross_reference(student_id, lesson_id)
VALUES((SELECT person_id FROM stud1), (SELECT lesson_id FROM individl)), --individual

		((SELECT person_id FROM stud1), (SELECT lesson_id FROM groupl)), --grouplesson
		((SELECT person_id FROM stud2), (SELECT lesson_id FROM groupl)),

		((SELECT person_id FROM stud1), (SELECT lesson_id FROM ensambl)), --ensamble
		((SELECT person_id FROM stud2), (SELECT lesson_id FROM ensambl));


--insert prices for lessons
INSERT INTO price(lesson_id, level, lesson_cost, valid_from)
VALUES((SELECT lesson_id FROM individl), 
		(SELECT level FROM individual WHERE lesson_id = (SELECT lesson_id FROM individl)), 60.00, '2022-01-01'),

	  ((SELECT lesson_id FROM groupl), (SELECT level FROM grouplesson WHERE lesson_id = (SELECT lesson_id FROM groupl)), 70.00, '2022-01-01'),

	  ((SELECT lesson_id FROM ensambl), NULL, 40.00, '2022-01-01');


--Database is now filled with example data.








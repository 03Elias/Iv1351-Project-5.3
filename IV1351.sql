-- Database: iv1351 Participants: Elias Gaghlasian, Ammar Alzeno, Leo Långberg CINTE ÅK 2

CREATE TYPE genre     AS ENUM('Classical', 'Jazz', 'Pop', 'Rock');
CREATE TYPE instrumentals AS ENUM('Piano', 'Guitar', 'Bass', 'Drums', 'Violin', 'Saxophone', 'Trumpet', 'Flute');
CREATE TYPE difficulty AS ENUM('Beginner','Intermediate','Advanced');


CREATE TABLE person (
  person_id SERIAL NOT NULL,
  name VARCHAR(100) NOT NULL,
  contact_details_tlf VARCHAR(100) NOT NULL,
  personal_number INT UNIQUE NOT NULL,
  address varchar(100) NOT NULL,
  PRIMARY KEY(person_id)
);
      CREATE TABLE student (
        student_id SERIAL REFERENCES person(person_id) ON DELETE CASCADE,
        PRIMARY KEY(student_id)
      );
          CREATE TABLE student_sibling (
            student_id  SERIAL REFERENCES student(student_id) ON DELETE CASCADE,
            sibling_id SERIAL REFERENCES student(student_id) ON DELETE CASCADE,
            PRIMARY KEY(student_id, sibling_id)
          );
            CREATE TABLE student_contact_person (
            student_id SERIAL REFERENCES student(student_id),
            contact_person_id SERIAL REFERENCES person(person_id),
            PRIMARY KEY(student_id, contact_person_id)
          );

CREATE TABLE instructor (
	instructor_id SERIAL REFERENCES person(person_id) ON DELETE CASCADE,
    PRIMARY KEY(instructor_id)
);

CREATE TABLE instructor_time_available (
     instructor_id SERIAL REFERENCES instructor(instructor_id) ON DELETE CASCADE,
     time_available TIMESTAMP NOT NULL,
     PRIMARY KEY(instructor_id, time_available)
);

CREATE TABLE instrument (
  instrument_id SERIAL NOT NULL,
  instrument_type_name instrumentals UNIQUE NOT NULL,
  PRIMARY KEY(instrument_id)
);

CREATE TABLE lesson (    
  lesson_id SERIAL NOT NULL, 
  student_count INT NOT NULL DEFAULT 0,
  min_students INT,
  max_students INT,  
  lesson_time TIMESTAMP NOT NULL,
  instructor_id SERIAL REFERENCES instructor(instructor_id), 
  PRIMARY KEY(lesson_id)
);

CREATE TABLE individual (
  lesson_id SERIAL REFERENCES lesson(lesson_id) ON DELETE CASCADE,
  level difficulty NOT NULL,
  instrument_id SERIAL REFERENCES instrument(instrument_id),
  PRIMARY KEY(lesson_id, instrument_id)  
);

CREATE TABLE grouplesson (
  lesson_id SERIAL REFERENCES lesson(lesson_id) ON DELETE CASCADE,
  level difficulty NOT NULL,
  instrument_id SERIAL REFERENCES instrument(instrument_id),
  PRIMARY KEY(lesson_id, instrument_id) 
);

CREATE TABLE ensamble (
  lesson_id SERIAL REFERENCES lesson(lesson_id) ON DELETE CASCADE,
  genres genre NOT NULL,
  PRIMARY KEY(lesson_id)
);


CREATE TABLE price (
  lesson_id SERIAL REFERENCES lesson(lesson_id),
  level difficulty,  
  lesson_cost        DOUBLE PRECISION NOT NULL,
  valid_from  TIMESTAMP NOT NULL,
  PRIMARY KEY(lesson_id, valid_from)
);

CREATE TABLE student_lesson_cross_reference (     
  lesson_id SERIAL REFERENCES lesson(lesson_id) ON DELETE CASCADE,
  student_id SERIAL REFERENCES student(student_id) ON DELETE CASCADE,
  PRIMARY KEY(lesson_id, student_id)
);


CREATE TABLE instrument_rental (  
  rental_id SERIAL NOT NULL, 
  brand VARCHAR(100),  
  cost DOUBLE PRECISION NOT NULL,
  time_rented   DATE NOT NULL,
  time_returned DATE,
  student_id SERIAL REFERENCES student(student_id),
  PRIMARY KEY(rental_id)
);

CREATE TABLE in_stock (
  instrument_id SERIAL REFERENCES instrument(instrument_id),
  rental_id SERIAL REFERENCES instrument_rental(rental_id),
  quantity INT NOT NULL,
  PRIMARY KEY(rental_id, instrument_id)
);


--TRIGGERS--
-- max 2 rented instruments (TRIGGER)
CREATE OR REPLACE FUNCTION check_max_rented_instruments()
RETURNS TRIGGER AS $$
BEGIN
  IF (
    SELECT COUNT(DISTINCT rental_id)
    FROM instrument_rental
    WHERE student_id = NEW.student_id
  ) >= 2 AND NEW.student_id IS NOT NULL THEN
    RAISE EXCEPTION 'A student can rent at most 2 instruments at the same time';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER max_rented_instruments_trigger
BEFORE INSERT OR UPDATE
ON instrument_rental
FOR EACH ROW
EXECUTE FUNCTION check_max_rented_instruments();

--if 'individual' then set min/max (TRIGGER)
CREATE OR REPLACE FUNCTION set_default_students_for_individual()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lesson
  SET min_students = COALESCE(min_students, 1),
      max_students = COALESCE(max_students, 1)
  WHERE lesson_id = NEW.lesson_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_default_students_for_individual_trigger
AFTER INSERT
ON individual
FOR EACH ROW
EXECUTE FUNCTION set_default_students_for_individual();

CREATE TRIGGER update_student_count_trigger
AFTER INSERT OR UPDATE
ON student_lesson_cross_reference
FOR EACH ROW
EXECUTE FUNCTION update_student_count();


--Symmetrical Sibling inserts--
CREATE OR REPLACE FUNCTION symmetrical_sibling_trigger()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO student_sibling(student_id, sibling_id)
  VALUES (NEW.sibling_id, NEW.student_id)
  ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER symmetrical_sibling
AFTER INSERT 
ON student_sibling
FOR EACH ROW
EXECUTE FUNCTION symmetrical_sibling_trigger();

--Symmetrical Sibling deletes--
CREATE OR REPLACE FUNCTION symmetrical_sibling_delete_trigger()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM student_sibling
  WHERE OLD.student_id = sibling_id OR OLD.sibling_id = student_id;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER symmetrical_sibling_del
AFTER DELETE
ON student_sibling
FOR EACH ROW
EXECUTE FUNCTION symmetrical_sibling_delete_trigger();


--student_count updated from student_lesson_cross_reference (TRIGGER)
CREATE OR REPLACE FUNCTION update_student_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE lesson
  SET student_count = (
    SELECT COUNT(slcr.student_id)
    FROM student_lesson_cross_reference slcr
    WHERE slcr.lesson_id = NEW.lesson_id
  )
  WHERE lesson_id = NEW.lesson_id;

  IF (
    SELECT COUNT(slcr.student_id)
    FROM student_lesson_cross_reference slcr
    WHERE slcr.lesson_id = NEW.lesson_id
  ) > (SELECT max_students FROM lesson WHERE lesson_id = NEW.lesson_id) THEN
    RAISE EXCEPTION 'Lesson is full. Cannot add more students.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION time_available_booked_function()
RETURNS TRIGGER AS $$
DECLARE
  t TIMESTAMP;  -- Declare a variable to store the result of the SELECT statement
BEGIN
  SELECT l.lesson_time
  INTO t
  FROM lesson l
  WHERE l.lesson_id = NEW.lesson_id;

  -- Check if there is a matching time_available in instructor_time_available
  IF EXISTS (
    SELECT 1
    FROM instructor_time_available
    WHERE time_available = t
  ) THEN
    -- If a match is found, delete the corresponding record in instructor_time_available
    DELETE FROM instructor_time_available WHERE time_available = t;
  ELSE
    -- If no match is found, raise an exception
    RAISE EXCEPTION 'Time not available for lesson_id: %', NEW.lesson_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

---individual makes use of the isntructor_time_available ---
CREATE TRIGGER time_available_booked
BEFORE INSERT
ON individual
FOR EACH ROW
EXECUTE FUNCTION time_available_booked_function();








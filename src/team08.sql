/*
 Team 8: Dāda Bäce
 Adam Nash awn10@pitt.edu
 Jason Henriquez jth79@pitt.edu
 Ethan Dewit erd56@pitt.edu
 */

--Q1
DROP TABLE IF EXISTS AIRLINE CASCADE;
DROP TABLE IF EXISTS FLIGHT CASCADE;
DROP TABLE IF EXISTS PLANE CASCADE;
DROP TABLE IF EXISTS PRICE CASCADE;
DROP TABLE IF EXISTS CUSTOMER CASCADE;
DROP TABLE IF EXISTS RESERVATION CASCADE;
DROP TABLE IF EXISTS RESERVATION_DETAIL CASCADE;
DROP TABLE IF EXISTS OURTIMESTAMP CASCADE;
DROP DOMAIN IF EXISTS EMAIL_DOMAIN CASCADE;

--Note: This is a simplified email domain and is not intended to exhaustively check for all requirements of an email
CREATE DOMAIN EMAIL_DOMAIN AS varchar(30)
    CHECK ( value ~ '^[a-zA-Z0-9.!#$%&''*+\/=?^_`{|}~\-]+@(?:[a-zA-Z0-9\-]+\.)+[a-zA-Z0-9\-]+$' );

CREATE TABLE AIRLINE (
  airline_id            integer,
  airline_name          varchar(50)     NOT NULL,
  airline_abbreviation  varchar(10)     NOT NULL,
  year_founded          integer         NOT NULL,
  CONSTRAINT AIRLINE_PK PRIMARY KEY (airline_id),
  CONSTRAINT AIRLINE_UQ1 UNIQUE (airline_name),
  CONSTRAINT AIRLINE_UQ2 UNIQUE (airline_abbreviation)
);

CREATE TABLE PLANE (
    plane_type      char(4),
    manufacturer    varchar(10)     NOT NULL,
    plane_capacity  integer         NOT NULL,
    last_service    date            NOT NULL,
    year            integer         NOT NULL,
    owner_id        integer         NOT NULL,
    CONSTRAINT PLANE_PK PRIMARY KEY (plane_type,owner_id),
    CONSTRAINT PLANE_FK FOREIGN KEY (owner_id) REFERENCES AIRLINE(airline_id)
);

CREATE TABLE FLIGHT (
    flight_number   integer,
    airline_id      integer     NOT NULL,
    plane_type      char(4)     NOT NULL,
    departure_city  char(3)     NOT NULL,
    arrival_city    char(3)     NOT NULL,
    departure_time  varchar(4)  NOT NULL,
    arrival_time    varchar(4)  NOT NULL,
    weekly_schedule varchar(7)  NOT NULL,
    CONSTRAINT FLIGHT_PK PRIMARY KEY (flight_number),
    CONSTRAINT FLIGHT_FK1 FOREIGN KEY (plane_type,airline_id) REFERENCES PLANE(plane_type,owner_id),
    CONSTRAINT FLIGHT_FK2 FOREIGN KEY (airline_id) REFERENCES AIRLINE(airline_id),
    CONSTRAINT FLIGHT_UQ UNIQUE (departure_city, arrival_city)
);

CREATE TABLE PRICE (
    departure_city  char(3),
    arrival_city    char(3),
    airline_id      integer,
    high_price      integer     NOT NULL,
    low_price       integer     NOT NULL,
    CONSTRAINT PRICE_PK PRIMARY KEY (departure_city, arrival_city),
    CONSTRAINT PRICE_FK FOREIGN KEY (airline_id) REFERENCES AIRLINE(airline_id),
    CONSTRAINT PRICE_CHECK_HIGH CHECK (high_price >= 0),
    CONSTRAINT PRICE_CHECK_LOW CHECK (low_price >= 0)
);

--Assuming salutation can be NULL as many people don't use salutations on online forms
--Assuming last_name can be NULL as not everyone has a last name, like Cher
--Assuming phone is optional (can be NULL) but email is required
--Assuming that duplicate first_name and last_name pairs are impossible since Task 1 necessitates this functionality
--Assuming that email addresses should be unique in the table since multiple customers shouldn't sign up with
---the same email
CREATE TABLE CUSTOMER (
    cid                 INTEGER,
    salutation          varchar(3),
    first_name          varchar(30)     NOT NULL,
    last_name           varchar(30),
    credit_card_num     varchar(16)     NOT NULL,
    credit_card_expire  date            NOT NULL,
    street              varchar(30)     NOT NULL,
    city                varchar(30)     NOT NULL,
    state               varchar(2)      NOT NULL,
    phone               varchar(10),
    email               EMAIL_DOMAIN    NOT NULL,
    frequent_miles      varchar(10),
    CONSTRAINT CUSTOMER_PK PRIMARY KEY (cid),
    CONSTRAINT CUSTOMER_FK FOREIGN KEY (frequent_miles) REFERENCES AIRLINE(airline_abbreviation),
    CONSTRAINT CUSTOMER_CCN CHECK (credit_card_num ~ '\d{16}'),
    CONSTRAINT CUSTOMER_UQ1 UNIQUE (credit_card_num),
    CONSTRAINT CUSTOMER_UQ2 UNIQUE (email),
    CONSTRAINT CUSTOMER_UQ3 UNIQUE (first_name, last_name)
);

--Assuming that a customer can make multiple reservations, i.e., cid and credit_card_num are not unique here
---since multiple reservations will have unique reservation_numbers
CREATE TABLE RESERVATION (
  reservation_number    integer,
  cid                   integer     NOT NULL,
  cost                  decimal     NOT NULL,
  credit_card_num       varchar(16) NOT NULL,
  reservation_date      timestamp   NOT NULL,
  ticketed              boolean     NOT NULL    DEFAULT FALSE,
  CONSTRAINT RESERVATION_PK PRIMARY KEY (reservation_number),
  CONSTRAINT RESERVATION_FK1 FOREIGN KEY (cid) REFERENCES CUSTOMER(cid),
  CONSTRAINT RESERVATION_FK2 FOREIGN KEY (credit_card_num) REFERENCES CUSTOMER(credit_card_num),
  CONSTRAINT RESERVATION_COST CHECK (cost >= 0)
);

CREATE TABLE RESERVATION_DETAIL (
  reservation_number    integer,
  flight_number         integer     NOT NULL,
  flight_date           timestamp   NOT NULL,
  leg                   integer,
  CONSTRAINT RESERVATION_DETAIL_PK PRIMARY KEY (reservation_number, leg),
  CONSTRAINT RESERVATION_DETAIL_FK1 FOREIGN KEY (reservation_number) REFERENCES RESERVATION(reservation_number) ON DELETE CASCADE,
  CONSTRAINT RESERVATION_DETAIL_FK2 FOREIGN KEY (flight_number) REFERENCES FLIGHT(flight_number),
  CONSTRAINT RESERVATION_DETAIL_CHECK_LEG CHECK (leg > 0)
);

-- The c_timestamp is initialized once using INSERT and updated subsequently
CREATE TABLE OURTIMESTAMP (
    c_timestamp     timestamp,
    CONSTRAINT OURTIMESTAMP_PK PRIMARY KEY (c_timestamp)
);


--Q2 getCancellationTime Function
CREATE OR REPLACE FUNCTION getCancellationTime(reservation_num integer)
    RETURNS timestamp AS
$$
DECLARE
    cancellation_time timestamp;
BEGIN
    SELECT (flight_date - INTERVAL '12 hours')
    INTO cancellation_time
    FROM RESERVATION_DETAIL
    WHERE reservation_number = reservation_num
      AND LEG = 1; -- ALTERNATIVE: ORDER BY flight_date FETCH FIRST ROW ONLY;

    RETURN cancellation_time;
END;
$$ LANGUAGE plpgsql;

-- Q3 Helper function
-- Gets the number of reservations for a specific flight and datetime
-- Returns NULL if the flight or/and the timestamp do not exist
CREATE OR REPLACE FUNCTION getNumberOfSeats(flight_num integer, flight_time timestamp)
    RETURNS INTEGER AS
$$
DECLARE
    result integer;
BEGIN
    SELECT COUNT(reservation_number)
    INTO result
    FROM reservation_detail
    WHERE flight_number = flight_num
      AND flight_date = flight_time
    GROUP BY flight_number, flight_date;

    RETURN result;
END;
$$ language plpgsql;

-- Returns true if the plane is full for a specific flight and datetime
CREATE OR REPLACE FUNCTION isPlaneFull(flight_num integer, flight_d timestamp)
    RETURNS BOOLEAN AS
$$
DECLARE
    max_capacity     integer;
    current_capacity integer;
    result           BOOLEAN := TRUE;
BEGIN
    --Get appropriate plane's capacity
    SELECT plane_capacity
    INTO max_capacity
    FROM PLANE AS P
             NATURAL JOIN (SELECT plane_type
                           FROM FLIGHT
                           WHERE FLIGHT.flight_number = flight_num) AS F;

    --Get number of seats filled on flight
    current_capacity = getNumberOfSeats(flight_num, flight_d);

    IF current_capacity IS NULL THEN
        RAISE 'No matching flight.';
    ELSEIF current_capacity < max_capacity THEN
        result := FALSE;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;


-- Returns true if the plane is full for a specific flight and datetime
-- Adaptation from isPlaneFull that returns true if flight does not exist
CREATE OR REPLACE FUNCTION isFull(flight_num integer, flight_d timestamp)
    RETURNS BOOLEAN AS
$$
DECLARE
    max_capacity     integer;
    current_capacity integer;
    result           BOOLEAN := TRUE;
BEGIN
    --Get appropriate plane's capacity
    SELECT plane_capacity
    INTO max_capacity
    FROM PLANE AS P
             NATURAL JOIN (SELECT plane_type
                           FROM FLIGHT
                           WHERE FLIGHT.flight_number = flight_num) AS F;

    --Get number of seats filled on flight
    current_capacity = getNumberOfSeats(flight_num, flight_d);

    IF current_capacity IS NULL THEN
        result := FALSE;
    ELSEIF current_capacity < max_capacity THEN
        result := FALSE;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;




-- Q4 Helper Functions
-- Check if the reservation exit and if the flight exist
CREATE OR REPLACE FUNCTION validateReservationInfo(reservation_num integer, flight_num integer)
    RETURNS BOOLEAN AS
$$
DECLARE
    reservation_exist BOOLEAN := FALSE;
    flight_exist      BOOLEAN := FALSE;
    result            BOOLEAN := FALSE;
BEGIN
    SELECT (reservation_number = reservation_num)
    INTO reservation_exist
    FROM reservation
    WHERE reservation_number = reservation_num;

    SELECT (flight_number = flight_num)
    INTO flight_exist
    FROM flight
    WHERE flight_number = flight_num;

    IF (reservation_exist IS NULL OR flight_exist IS NULL) THEN
        result := FALSE;
    ELSE
        result := reservation_exist AND flight_exist;
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql;


-- Get a letter if there is a flight or '-' if there isn't one
CREATE OR REPLACE FUNCTION getDayLetterFromSchedule(departure_date date, flight_num integer)
    RETURNS VARCHAR AS
$$
DECLARE
    day_of_week integer;
    weekly      varchar(7);
    day         varchar(1);
BEGIN
    SELECT EXTRACT(dow FROM departure_date) INTO day_of_week;

    SELECT weekly_schedule
    INTO weekly
    FROM FLIGHT AS F
    WHERE F.flight_number = flight_num;

    --CAUTION: substring function is one-index based and not zero
    SELECT substring(weekly from (day_of_week + 1) for 1) INTO day;

    RETURN day;
END;
$$ language plpgsql;

-- Calculate the departure time based on the date and the flight schedule
CREATE OR REPLACE FUNCTION getCalculatedDepartureDate(departure_date date, flight_num integer)
    RETURNS timestamp AS
$$
DECLARE
    flight_time varchar(5);
BEGIN
    SELECT (substring(DEPT_TABLE.departure_time from 1 for 2) || ':' ||
            substring(DEPT_TABLE.departure_time from 3 for 2))
    INTO flight_time
    FROM (SELECT departure_time
          FROM FLIGHT AS F
          WHERE F.flight_number = flight_num) AS DEPT_TABLE;

    RETURN to_timestamp(departure_date || ' ' || flight_time, 'YYYY-MM-DD HH24:MI');
END;
$$ language plpgsql;

-- Q4 makeReservation Procedure
CREATE OR REPLACE PROCEDURE makeReservation(reservation_num integer, flight_num integer, departure_date date,
                                            leg_trip integer)
AS
$$
DECLARE
    information_valid      BOOLEAN := FALSE;
    calculated_flight_date timestamp;
    day                    varchar(1);
BEGIN

    -- make sure arguments are valid
    information_valid = validateReservationInfo(reservation_num, flight_num);

    IF (NOT information_valid) THEN
        RAISE EXCEPTION 'reservation number and/or flight number not valid';
    END IF;

    -- get the letter day from flight schedule corresponding to customer desired departure
    day = getDayLetterFromSchedule(departure_date, flight_num);

    IF day = '-' THEN
        RAISE EXCEPTION 'no available flights on desired departure day';
    END IF;

    -- check flight schedule to get the exact flight_date
    calculated_flight_date = getCalculatedDepartureDate(departure_date, flight_num);

    -- make the reservation
    INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
    VALUES (reservation_num, flight_num, calculated_flight_date, leg_trip);
END;
$$ LANGUAGE plpgsql;

--Q5 planeUpgrade Trigger
--Trigger Function for upgrading Plane
CREATE OR REPLACE PROCEDURE upgradePlaneHelper(flight_num integer, flight_time timestamp) AS
$$
DECLARE
    numberOfSeats    integer;
    upgradeFound     boolean := FALSE;
    currentPlaneType varchar(4);
    airplane_row     RECORD;
    airlinePlanes CURSOR FOR
        SELECT p.plane_type, p.plane_capacity
        FROM flight f
                 JOIN plane p ON f.airline_id = p.owner_id
        WHERE f.flight_number = flight_num
        ORDER BY plane_capacity;
BEGIN
    -- get number of seats for the flight
    numberOfSeats = getNumberOfSeats(flight_num, flight_time);
    raise notice '% number of seats for %', numberOfSeats, flight_num;

    -- get plane type
    SELECT plane_type
    INTO currentPlaneType
    FROM flight
    WHERE flight_number = flight_num;

    -- open cursor
    OPEN airlinePlanes;

    -- check if another plane owned by the airlines can fit current seats
    LOOP
        -- get next plane
        FETCH airlinePlanes INTO airplane_row;
        --exit when done
        EXIT WHEN NOT FOUND;

        -- found a plane can fit (we are starting from the smallest)
        IF numberOfSeats IS NULL OR numberOfSeats + 1 <= airplane_row.plane_capacity THEN
            upgradeFound := TRUE;
            raise notice '% should be upgraded', flight_num;
            -- if the next smallest plane can fit is not the one already scheduled for the flight, then change it
            IF airplane_row.plane_type <> currentPlaneType THEN
                raise notice '% is being upgraded to %', flight_num, airplane_row.plane_type;
                UPDATE flight SET plane_type = airplane_row.plane_type WHERE flight_number = flight_num;
            END IF;
            -- mission accomplished (either we changed the plane OR it is already the next smallest we can fit)
            EXIT;
        END IF;

    END LOOP;

    -- close cursor
    CLOSE airlinePlanes;
    IF NOT upgradeFound THEN
        RAISE EXCEPTION 'There is not any upgrade for the flight % on %',flight_num,flight_time;
    END IF;
END;
$$ language plpgsql;


CREATE OR REPLACE FUNCTION upgradePlane()
    RETURNS TRIGGER AS
$$
BEGIN
    raise notice '% is attempting upgrading', new.flight_number;
    -- downgrade plane in case it is upgradable
    CALL upgradePlaneHelper(new.flight_number, new.flight_date);
    RETURN NEW;
END;
$$ language plpgsql;

DROP TRIGGER IF EXISTS upgradePlane ON RESERVATION_DETAIL;
CREATE TRIGGER upgradePlane
    BEFORE INSERT
    ON RESERVATION_DETAIL
    FOR EACH ROW
EXECUTE PROCEDURE upgradePlane();

--Q6 cancelReservation Trigger
CREATE OR REPLACE PROCEDURE downgradePlaneHelper(flight_num integer, flight_time timestamp)
AS
$$
DECLARE
    numberOfSeats    integer;
    currentPlaneType varchar(4);
    airplane_row     RECORD;
    airlinePlanes CURSOR FOR
        SELECT p.plane_type, p.plane_capacity
        FROM flight f
                 JOIN plane p ON f.airline_id = p.owner_id
        WHERE f.flight_number = flight_num
        ORDER BY plane_capacity;
BEGIN
    -- get number of seats for the flight
    numberOfSeats = getNumberOfSeats(flight_num, flight_time);
    raise notice '% number of seats for %', numberOfSeats, flight_num;

    -- get plane type
    SELECT plane_type
    INTO currentPlaneType
    FROM flight
    WHERE flight_number = flight_num;

    -- open cursor
    OPEN airlinePlanes;

    -- check if another plane owned by the airlines can fit current seats
    LOOP
        -- get next plane
        FETCH airlinePlanes INTO airplane_row;
        --exit when done
        EXIT WHEN NOT FOUND;

        -- found a plane can fit (we are starting from the smallest)
        IF numberOfSeats - 1 <= airplane_row.plane_capacity THEN
            raise notice '% should be downgraded', flight_num;
            -- if the smallest plane can fit is not the one already scheduled for the flight, then change it
            IF airplane_row.plane_type <> currentPlaneType THEN
                raise notice '% is being downgraded to %', flight_num, airplane_row.plane_type;
                UPDATE flight SET plane_type = airplane_row.plane_type WHERE flight_number = flight_num;
            END IF;
            -- mission accomplished (either we changed the plane OR it is already the smallest we can fit)
            EXIT;
        END IF;

    END LOOP;

    -- close cursor
    CLOSE airlinePlanes;

END;
$$ language plpgsql;

CREATE OR REPLACE FUNCTION planeDowngrade()
    RETURNS TRIGGER AS
$$
BEGIN
    raise notice '% is attempting downgrading', new.flight_number;
    CALL downgradePlaneHelper(new.flight_number, new.flight_date);
    RETURN NEW;
END;
$$ language plpgsql;

DROP TRIGGER IF EXISTS planeDowngrade ON RESERVATION_DETAIL;
CREATE TRIGGER planeDowngrade
    AFTER DELETE
    ON RESERVATION_DETAIL
    FOR EACH ROW
EXECUTE PROCEDURE planeDowngrade();

SELECT getNumberOfSeats(3, TO_TIMESTAMP('11-05-2020 14:15', 'MM-DD-YYYY HH24:MI')::timestamp without time zone);
SELECT plane_type from flight where flight_number = 3;
-- should return 1 and t001

CREATE OR REPLACE FUNCTION reservationCancellation()
    RETURNS TRIGGER AS
$$
DECLARE
    currentTime      timestamp;
    cancellationTime timestamp;
    reservation_row  RECORD;
    reservations CURSOR FOR
        SELECT *
        FROM (SELECT DISTINCT reservation_number
              FROM RESERVATION AS R
              WHERE R.ticketed = FALSE) AS NONTICKETED
                 NATURAL JOIN (SELECT DISTINCT reservation_number, flight_date, flight_number
                               FROM RESERVATION_DETAIL AS RD
                               WHERE (RD.flight_date >= currentTime)) AS CANCELLABLEFLIGHT ;
BEGIN
    -- capture our simulated current time
    currentTime := new.c_timestamp;

    -- open cursor
    OPEN reservations;

    LOOP
        -- get the next reservation number that is not ticketed
        FETCH reservations INTO reservation_row;

        -- exit loop when all records are processed
        EXIT WHEN NOT FOUND;

        -- get the cancellation time for the fetched reservation
        cancellationTime = getcancellationtime(reservation_row.reservation_number);
        raise notice 'cancellationTime = % and currentTime = %', cancellationTime,currentTime;
        -- delete customer reservation if departures is less than or equal 12 hrs
        IF (cancellationTime <= currentTime) THEN
            raise notice '% is being cancelled', reservation_row.reservation_number;
            -- delete the reservation
            DELETE FROM RESERVATION WHERE reservation_number = reservation_row.reservation_number;
            --raise notice '% is attempting downgrading', reservation_row.flight_number;
            --CALL downgradePlaneHelper(reservation_row.flight_number, reservation_row.flight_date);
        END IF;

    END LOOP;
    -- close cursor
    CLOSE reservations;

    RETURN new;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cancelReservation ON ourtimestamp;
CREATE TRIGGER cancelReservation
    AFTER UPDATE
    ON OURTIMESTAMP
    FOR EACH ROW
EXECUTE PROCEDURE reservationCancellation();

--TRIGGER 3 FOR FINAL PROJECT: Frequent Flyer
--DELETE FROM ourtimestamp; -- VALUES('2020-11-03 20:25:00');
CREATE OR REPLACE FUNCTION frequentFlyer()
    RETURNS TRIGGER AS
$$
DECLARE
    currentTime timestamp;
    freqAirline varchar(10);
    airline_legs_row  RECORD;
    airline_new varchar(20)= (SELECT f.airline_id
                                from reservation_detail rd natural join reservation r natural Join flight f
                                where new.reservation_number = reservation_number);

    count integer;

    pastFlights CURSOR FOR
    SELECT airline_id, sum(cost) FROM (SELECT airline_id, cost, RANK () OVER (ORDER BY legs DESC) leg_rank
    FROM (  SELECT airline_id, count(leg) AS legs, cost
            FROM reservation_detail JOIN flight ON reservation_detail.flight_number = flight.flight_number NATURAL JOIN reservation
            WHERE cid = new.cid and reservation.ticketed = 'true'
            GROUP BY airline_id, cost) legsByAirline) rankedAirlines
    WHERE leg_rank = 1
    GROUP BY airline_id
    ORDER BY sum(cost) DESC;

BEGIN

    -- open cursor
    OPEN pastFlights;
    LOOP
        -- get the most airline legcounts for cid
        FETCH pastFlights INTO airline_legs_row;
        -- exit loop when all records are processed
        EXIT WHEN NOT FOUND;
       IF ((Select count(*) from airline_legs_row)  = 1) THEN
            freqAirline := (SELECT airline_abbreviation
                            from airline
                            where airline.airline_id = airline_legs_row.airline_id);
        END IF;
        --if tied on #legs and total cost, check if current reservation is one of the ties
        IF (airline_new = airline_legs_row.airline_id) THEN
            freqAirline := (SELECT airline_abbreviation
                            from airline
                            where airline.airline_id = airline_legs_row.airline_id);
        ELSE
            --if airline in new reservation is not part of the tie, pick the first record
            freqAirline := (SELECT airline_abbreviation
                            from airline
                            where airline.airline_id = airline_legs_row.airline_id);
        END IF;

        UPDATE Customer SET frequent_miles = freqAirline WHERE cid = new.cid;
    END LOOP;

    -- close cursor
    CLOSE pastFlights;

    RETURN freqAirline;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS frequentFlyer ON reservation;
CREATE TRIGGER frequentFlyer
    AFTER INSERT OR UPDATE
    ON reservation
    for each statement
EXECUTE PROCEDURE frequentflyer();

CREATE OR REPLACE FUNCTION getCalculatedArrivalDate(departure_date date, flight_num integer)
    RETURNS timestamp AS
$$
DECLARE
    arrive_time varchar(5);
    depart_time varchar(5);
    arrive timestamp;
    depart timestamp;
    arrivalDate timestamp;
BEGIN
    SELECT (substring(ARVL_TABLE.arrival_time from 1 for 2) || ':' ||
            substring(ARVL_TABLE.arrival_time from 3 for 2))
    INTO arrive_time
    FROM (SELECT arrival_time
          FROM FLIGHT AS F
          WHERE F.flight_number = flight_num) AS ARVL_TABLE;

    SELECT (substring(DEPT_TABLE.arrival_time from 1 for 2) || ':' ||
            substring(DEPT_TABLE.arrival_time from 3 for 2))
    INTO depart_time
    FROM (SELECT arrival_time
          FROM FLIGHT AS F
          WHERE F.flight_number = flight_num) AS DEPT_TABLE;

    arrivalDate:= to_timestamp(departure_date || ' ' || arrive_time, 'YYYY-MM-DD HH24:MI');
    depart := to_timestamp(depart_time, 'HH24:MI');
    arrive := to_timestamp(arrive_time, 'HH24:MI');

    if arrive < depart then
        arrivalDate := arrivalDate + interval '1 day';
    end if;
    return arrivalDate;
END;
$$ language plpgsql;

--returns True if low price, false if high price
create or replace function highOrLow(resNumber integer) returns boolean as
$$
declare
    firstLeg record;
    lastLeg record;
    depart timestamp;
    arrive timestamp;
begin
    select *
    into    lastLeg
    from    reservation_detail
    where   resNumber = reservation_number and
            leg = 1;

    select  *
    into    firstLeg
    from    reservation_detail
    where   resNumber = reservation_number and
            leg = (select max(leg) from reservation_detail where reservation_number = resNumber);

--    select max(leg) from reservation_detail where reservation_number =

--    raise warning 'Made it to arrive';
    depart := getcalculateddeparturedate(firstLeg.flight_date::date, firstLeg.flight_number);
    arrive := getcalculatedarrivaldate(lastLeg.flight_date::date, firstLeg.flight_number);

--    raise warning 'DOW from depart is: %', extract(DOW from depart);
--    raise warning 'dow from arrive is: %', extract(dow from arrive);
    if extract(DOW from depart) != extract (DOW from arrive) then
        return true;
    else
        return false;
    end if;
end;
$$ language plpgsql;

--Edits the overall price for a reservation when the flight cost changes
create or replace function priceEdit()
returns trigger as
$$
declare
    highLow boolean;
    needsUpdate cursor for  select distinct reservation_number
                            from    reservation_detail r,
                                    (select  f.flight_number
                                    from    flight f
                                    where   new.arrival_city = f.arrival_city and
                                            new.departure_city = f.departure_city)
                                    as s
                            where r.flight_number = s.flight_number;
    newPrice integer;
    resNumber record;

begin
--  raise warning 'New Values Are %, %, %', new.departure_city, new.arrival_city, new.low_price;
    open needsUpdate;
    loop

        fetch needsUpdate into resNumber;
        exit when not found;

        highLow := highOrLow(resNumber.reservation_number);

--        raise warning 'highLow value us: %', highLow;

        if highLow = true then

            select sum(low_price)
            from price natural join(select  airline_id, departure_city, arrival_city
                                    from    flight f, reservation_detail r
                                    where   f.flight_number = r.flight_number and
                                            r.reservation_number = resNumber.reservation_number) as cost
            into newPrice;
        else
            select sum(high_price)
            from price natural join(select  airline_id, departure_city, arrival_city
                                    from    flight f, reservation_detail r
                                    where   f.flight_number = r.flight_number and
                                            r.reservation_number = resNumber.reservation_number) as cost
            into newPrice;
        end if;

       -- raise warning 'New Price is: %', newPrice;

        update reservation
        set cost = newPrice
        where reservation_number = resNumber.reservation_number;

    end loop;

    close needsUpdate;
    return new;
end
$$ language plpgsql;



drop trigger if exists adjustTicket on price;
create trigger adjustTicket
    after update
    on price
    for each row
    execute procedure priceEdit();

--Sets the reservation cost given reservation_number rn
create or replace procedure setReservationCost(rn int)
AS
$$
DECLARE
    highLow boolean;
    newPrice integer;
BEGIN
    highLow := highOrLow(rn);

--        raise warning 'highLow value us: %', highLow;

        if highLow = true then

            select sum(low_price)
            from price natural join(select  airline_id, departure_city, arrival_city
                                    from    flight f, reservation_detail r
                                    where   f.flight_number = r.flight_number and
                                            r.reservation_number = rn) as cost
            into newPrice;
        else
            select sum(high_price)
            from price natural join(select  airline_id, departure_city, arrival_city
                                    from    flight f, reservation_detail r
                                    where   f.flight_number = r.flight_number and
                                            r.reservation_number = rn) as cost
            into newPrice;
        end if;

       -- raise warning 'New Price is: %', newPrice;

        update reservation
        set cost = newPrice
        where reservation_number = rn;
END;
$$ language plpgsql;

--Retrieves the flight prices along with the appropriate flight number
drop view if exists flightPrice cascade;
create view flightPrice as
    select  flight_number, f.airline_id, high_price, low_price
    from    flight f, price p
    where   f.arrival_city = p.arrival_city and
            f.departure_city = p.departure_city and
            f.airline_id = p.airline_id;

--Retrieves all of the customers who pay low pricing and puts associated price with each leg
drop view if exists lowPayers cascade;
create view lowPayers as
    select  cid, airline_id, low_price as price
    from    reservation r natural join reservation_detail rd, flightPrice f
    where   highOrLow(reservation_number) = true and
            rd.flight_number = f.flight_number and
            ticketed = true;

--Retrieves all of the customers who payed high pricing and puts associated price with each leg
drop view if exists highPayers cascade;
create view highPayers as
    select  cid, airline_id, high_price as price
    from    reservation r natural join reservation_detail rd, flightPrice f
    where   highOrLow(reservation_number) = false and
            rd.flight_number = f.flight_number and
            ticketed = true;

--Gets the full name and total cost spent on each airline of customers who have payed
drop view if exists topPayers cascade;
create view topPayers as
    select  concat(c.salutation, ' ', c.first_name, ' ', c.last_name) as name,
            airline_id, sum(a.price) as price
    from    (select * from highPayers union select * from lowPayers) as a, customer c
    where   c.cid = a.cid
    group by name, airline_id;

create or replace function departureFrom(varchar(3))
returns setof flight as $$
begin
    return query select * from flight where departure_city = $1;
end;
$$ language plpgsql;


--how many unique ticketed customers for each airline
drop view if exists ticketed_by_airline;
create or replace view ticketed_by_airline as
select airline_id, count(DISTINCT cid) ticketed_customers from reservation natural join reservation_detail natural join flight
WHERE ticketed
group by airline_id;


/*

OTHER TEST DATA WAS USED BUT IS NOT INCLUDED IN THIS FILE

 */




INSERT INTO AIRLINE (airline_id, airline_name, airline_abbreviation, year_founded)
VALUES (1, 'Alaska Airlines', 'ALASKA', 1932);
INSERT INTO AIRLINE (airline_id, airline_name, airline_abbreviation, year_founded)
VALUES (2, 'Allegiant Air', 'ALLEGIANT', 1997);
INSERT INTO AIRLINE (airline_id, airline_name, airline_abbreviation, year_founded)
VALUES (3, 'American Airlines', 'AMERICAN', 1926);
INSERT INTO AIRLINE (airline_id, airline_name, airline_abbreviation, year_founded)
VALUES (4, 'Delta Air Lines', 'DELTA', 1924);
INSERT INTO AIRLINE (airline_id, airline_name, airline_abbreviation, year_founded)
VALUES (5, 'United Airlines', 'UNITED', 1926);


--INSERT values of PLANE Table

INSERT INTO PLANE (plane_type, manufacturer, plane_capacity, last_service, year, owner_id)
VALUES ('A320', 'Airbus', 186, TO_DATE('11-03-2020', 'MM-DD-YYYY'), 1988, 1);
INSERT INTO PLANE (plane_type, manufacturer, plane_capacity, last_service, year, owner_id)
VALUES ('E175', 'Embraer', 76, TO_DATE('10-22-2020', 'MM-DD-YYYY'), 2004, 2);
INSERT INTO PLANE (plane_type, manufacturer, plane_capacity, last_service, year, owner_id)
VALUES ('B737', 'Boeing', 125, TO_DATE('09-09-2020', 'MM-DD-YYYY'), 2006, 3);
INSERT INTO PLANE (plane_type, manufacturer, plane_capacity, last_service, year, owner_id)
VALUES ('E145', 'Embraer', 50, TO_DATE('06-15-2020', 'MM-DD-YYYY'), 2018, 4);
INSERT INTO PLANE (plane_type, manufacturer, plane_capacity, last_service, year, owner_id)
VALUES ('B777', 'Boeing', 368, TO_DATE('09-16-2020', 'MM-DD-YYYY'), 1995, 5);


--INSERT values of FLIGHT Table

INSERT INTO FLIGHT (flight_number, airline_id, plane_type, departure_city, arrival_city, departure_time, arrival_time,
                    weekly_schedule)
VALUES (1, 1, 'A320', 'PIT', 'JFK', '1355', '1730', 'SMTWTFS');
INSERT INTO FLIGHT (flight_number, airline_id, plane_type, departure_city, arrival_city, departure_time, arrival_time,
                    weekly_schedule)
VALUES (2, 2, 'E175', 'JFK', 'LAX', '0825', '1845', '-MTWTFS');
INSERT INTO FLIGHT (flight_number, airline_id, plane_type, departure_city, arrival_city, departure_time, arrival_time,
                    weekly_schedule)
VALUES (3, 3, 'B737', 'LAX', 'SEA', '1415', '1725', 'SMT-TFS');
INSERT INTO FLIGHT (flight_number, airline_id, plane_type, departure_city, arrival_city, departure_time, arrival_time,
                    weekly_schedule)
VALUES (4, 4, 'E145', 'SEA', 'IAH', '1005', '2035', 'SMTW--S');
INSERT INTO FLIGHT (flight_number, airline_id, plane_type, departure_city, arrival_city, departure_time, arrival_time,
                    weekly_schedule)
VALUES (5, 5, 'B777', 'IAH', 'PIT', '0630', '1620', '-MTW--S');


--INSERT values of PRICE Table

INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('PIT', 'JFK', 1, 300, 165);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('JFK', 'LAX', 2, 480, 345);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('LAX', 'SEA', 3, 380, 270);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('SEA', 'IAH', 4, 515, 365);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('IAH', 'PIT', 5, 435, 255);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('JFK', 'PIT', 1, 440, 315);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('LAX', 'PIT', 2, 605, 420);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('SEA', 'LAX', 3, 245, 150);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('IAH', 'SEA', 4, 395, 260);
INSERT INTO PRICE (departure_city, arrival_city, airline_id, high_price, low_price)
VALUES ('PIT', 'IAH', 5, 505, 350);


--INSERT values of CUSTOMER Table

INSERT INTO CUSTOMER (cid, salutation, first_name, last_name, credit_card_num, credit_card_expire, street, city, state,
                      phone, email, frequent_miles)
VALUES (1, 'Mr', 'Jon', 'Smith', '6859941825383380', TO_DATE('04-13-2022', 'MM-DD-YYYY'), 'Bigelow Boulevard',
        'Pittsburgh', 'PA', '412222222', 'jsmith@gmail.com', 'ALASKA');
INSERT INTO CUSTOMER (cid, salutation, first_name, last_name, credit_card_num, credit_card_expire, street, city, state,
                      phone, email, frequent_miles)
VALUES (2, 'Mrs', 'Latanya', 'Wood', '7212080255339668', TO_DATE('07-05-2023', 'MM-DD-YYYY'), 'Houston Street',
        'New York', 'NY', '7187181717', 'lw@aol.com', 'ALLEGIANT');
INSERT INTO CUSTOMER (cid, salutation, first_name, last_name, credit_card_num, credit_card_expire, street, city, state,
                      phone, email, frequent_miles)
VALUES (3, 'Ms', 'Gabriella', 'Rojas', '4120892825130802', TO_DATE('09-22-2024', 'MM-DD-YYYY'), 'Melrose Avenue',
        'Los Angeles', 'CA', '2133234567', 'gar@yahoo.com', 'AMERICAN');
INSERT INTO CUSTOMER (cid, salutation, first_name, last_name, credit_card_num, credit_card_expire, street, city, state,
                      phone, email, frequent_miles)
VALUES (4, 'Mr', 'Abbas', 'Malouf', '4259758505178751', TO_DATE('10-17-2021', 'MM-DD-YYYY'), 'Pine Street', 'Seattle',
        'WA', '2066170345', 'malouf.a@outlook.com', 'DELTA');
INSERT INTO CUSTOMER (cid, salutation, first_name, last_name, credit_card_num, credit_card_expire, street, city, state,
                      phone, email, frequent_miles)
VALUES (5, 'Ms', 'Amy', 'Liu', '2538244543760285', TO_DATE('03-24-2022', 'MM-DD-YYYY'), 'Amber Drive', 'Houston', 'TX',
        '2818880102', 'amyliu45@icloud.com', 'UNITED');


--INSERT values of RESERVATION Table

INSERT INTO RESERVATION (reservation_number, cid, cost, credit_card_num, reservation_date, ticketed)
VALUES (1, 1, 1160, '6859941825383380', TO_TIMESTAMP('11-02-2020 10:55', 'MM-DD-YYYY HH24:MI'), TRUE);
INSERT INTO RESERVATION (reservation_number, cid, cost, credit_card_num, reservation_date, ticketed)
VALUES (2, 2, 620, '7212080255339668', TO_TIMESTAMP('11-22-2020 14:25', 'MM-DD-YYYY HH24:MI'), TRUE);
INSERT INTO RESERVATION (reservation_number, cid, cost, credit_card_num, reservation_date, ticketed)
VALUES (3, 3, 380, '4120892825130802', TO_TIMESTAMP('11-05-2020 17:20', 'MM-DD-YYYY HH24:MI'), FALSE);
INSERT INTO RESERVATION (reservation_number, cid, cost, credit_card_num, reservation_date, ticketed)
VALUES (4, 4, 255, '4259758505178751', TO_TIMESTAMP('12-01-2020 06:05', 'MM-DD-YYYY HH24:MI'), TRUE);
INSERT INTO RESERVATION (reservation_number, cid, cost, credit_card_num, reservation_date, ticketed)
VALUES (5, 5, 615, '2538244543760285', TO_TIMESTAMP('10-28-2020 22:45', 'MM-DD-YYYY HH24:MI'), FALSE);


--INSERT values of RESERVATION_DETAIL Table

INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (1, 1, TO_TIMESTAMP('11-02-2020 13:55', 'MM-DD-YYYY HH24:MI'), 1);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (1, 2, TO_TIMESTAMP('11-04-2020 08:25', 'MM-DD-YYYY HH24:MI'), 2);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (1, 3, TO_TIMESTAMP('11-05-2020 14:15', 'MM-DD-YYYY HH24:MI'), 3);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (2, 4, TO_TIMESTAMP('12-14-2020 10:05', 'MM-DD-YYYY HH24:MI'), 1);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (2, 5, TO_TIMESTAMP('12-15-2020 06:30', 'MM-DD-YYYY HH24:MI'), 2);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (3, 3, TO_TIMESTAMP('11-05-2020 14:15', 'MM-DD-YYYY HH24:MI'), 1);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (4, 5, TO_TIMESTAMP('12-15-2020 06:30', 'MM-DD-YYYY HH24:MI'), 1);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (5, 2, TO_TIMESTAMP('11-04-2020 08:25', 'MM-DD-YYYY HH24:MI'), 1);
INSERT INTO RESERVATION_DETAIL (reservation_number, flight_number, flight_date, leg)
VALUES (5, 3, TO_TIMESTAMP('11-05-2020 14:15', 'MM-DD-YYYY HH24:MI'), 2);

--INSERT values of OURTIMESTAMP Table
BEGIN;
INSERT INTO OURTIMESTAMP (c_timestamp)
VALUES (TO_TIMESTAMP('11-05-2020 02:15', 'MM-DD-YYYY HH24:MI'));
COMMIT;

BEGIN;
UPDATE OURTIMESTAMP
SET c_timestamp = TO_TIMESTAMP('11-03-2020 20:25', 'MM-DD-YYYY HH24:MI')
WHERE c_timestamp =  TO_TIMESTAMP('11-05-2020 02:15', 'MM-DD-YYYY HH24:MI');
COMMIT;

BEGIN;
UPDATE OURTIMESTAMP
SET c_timestamp = TO_TIMESTAMP('12-13-2020 22:05', 'MM-DD-YYYY HH24:MI')
WHERE c_timestamp =  TO_TIMESTAMP('11-03-2020 20:25', 'MM-DD-YYYY HH24:MI');
COMMIT;
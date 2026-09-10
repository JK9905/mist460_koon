/*
-- in your master database

CREATE LOGIN NandaSurendra

WITH PASSWORD = 'MI$T460Instructor';

-- switch to your mist460-rdb-lastname database;

CREATE USER NandaSurendra

FOR LOGIN NandaSurendra;

ALTER ROLE db_owner ADD MEMBER NandaSurendra;
*/

drop table if exists RoomReservation;
drop table if exists RoomAvailability;
drop table if exists AppUser;
drop table if exists Room;
go

create table Room
(
    RoomID int identity(1,1) primary key,
    RoomNumber varchar(10) not null,
    Floor int not null,
    Seats int not null,
    Whiteboard bit not null, -- for true or false
    Currentstatus bit not null
);

go

create table RoomAvailability
(
    RoomAvailabilityID int identity(1,1) primary key,
    RoomID int not null,
    AvailableDate date not null,
    AvailableStartTime time not null,
    AvailableEndTime time not null,
    AvailableStatus bit not null,
    constraint FK_RoomAvailability_Room foreign key (RoomID) references Room(RoomID)
);

go

create table AppUser
(
    AppUserID int identity(1,1) primary key,
    UserEmail varchar(50) not null,
    UserPassword varchar(50) not null
);

go

create table RoomReservation
(
    RoomReservationID int identity(1,1) primary key,
    RoomAvailabilityID int not null,
    ReservationDate date not null,
    ReservationStartTime time not null,
    ReservationEndTime time not null,
    ReservedByUser int not null,
    constraint FK_RoomReservation_AppUser foreign key (ReservedByUser) references AppUser(AppUserID),
    constraint FK_RoomReservation_RoomAvailability foreign key (RoomAvailabilityID) references RoomAvailability(RoomAvailabilityID)
);
/*
-- in your master database

CREATE LOGIN NandaSurendra
WITH PASSWORD = 'MI$T460Instructor';

-- switch to your mist460-rdb-lastname database;

CREATE USER NandaSurendra
FOR LOGIN NandaSurendra;

ALTER ROLE db_owner ADD MEMBER NandaSurendra;
*/

-- drop in FK-dependency order
drop table if exists SensorLog;
drop table if exists Sensor;
drop table if exists RoomAvailability;
drop table if exists Reservation;
drop table if exists AppUser;
drop table if exists Room;
go

create table Room
(
    RoomID int identity(1,1) primary key,
    RoomNumber varchar(10) not null unique,
    Floor int not null,
    Seats int not null,
    Whiteboard bit not null, -- for true or false
    CurrentStatus varchar(20) not null default 'Available'
        constraint CK_Room_CurrentStatus check (CurrentStatus in ('Available', 'In Use'))
);

go

create table AppUser
(
    AppUserID int identity(1,1) primary key,
    Email varchar(100) not null unique,
    Password varchar(200) not null -- store a hash, never plain text, in a real system
);

go

create table Reservation
(
    ReservationID int identity(1,1) primary key,
    AppUserID int not null,
    ReservationDateTime datetime not null default getdate(), -- when the reservation was made
    CheckInDateTime datetime null,
    CheckOutDateTime datetime null,
    TotalTime as datediff(minute, CheckInDateTime, CheckOutDateTime), -- minutes, computed
    ReservationStatus varchar(20) not null default 'Reserved'
        constraint CK_Reservation_Status check (ReservationStatus in ('Reserved', 'CheckedIn', 'CheckedOut', 'Cancelled')),
    constraint FK_Reservation_AppUser foreign key (AppUserID) references AppUser(AppUserID),
    constraint CK_Reservation_CheckOutAfterCheckIn check (CheckOutDateTime is null or CheckOutDateTime >= CheckInDateTime)
);

go

create table RoomAvailability
(
    RoomAvailabilityID int identity(1,1) primary key,
    RoomID int not null,
    AvailableDate date not null,
    StartTime time not null,
    EndTime time not null,
    AvailabilityStatus varchar(20) not null default 'Available'
        constraint CK_RoomAvailability_Status check (AvailabilityStatus in ('Available', 'Reserved')),
    ReservationID int null, -- null until this 15-min slot is included in a reservation
    constraint FK_RoomAvailability_Room foreign key (RoomID) references Room(RoomID),
    constraint FK_RoomAvailability_Reservation foreign key (ReservationID) references Reservation(ReservationID),
    constraint UQ_RoomAvailability_Slot unique (RoomID, AvailableDate, StartTime),
    constraint CK_RoomAvailability_TimeOrder check (EndTime > StartTime),
    constraint CK_RoomAvailability_15MinSlot check (datediff(minute, StartTime, EndTime) = 15) -- atomic 15-minute increments
);

go

create table Sensor
(
    SensorID int identity(1,1) primary key,
    RoomID int not null,
    InstallationDate datetime not null default getdate(),
    constraint FK_Sensor_Room foreign key (RoomID) references Room(RoomID)
)

go

create table SensorLog
(
    SensorLogID int identity(1,1) primary key,
    SensorID int not null,
    EntryDateTime datetime not null,
    ExitDateTime datetime null,
    constraint FK_SensorLog_Sensor foreign key (SensorID) references Sensor(SensorID)
)
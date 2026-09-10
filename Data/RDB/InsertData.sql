insert into Room (RoomNumber, Floor, Seats, Whiteboard, Currentstatus) values
--Room seats should only be 1-8 
('101', 1, 8, 1, 1),
('102', 1, 6, 0, 1),
('201', 2, 8, 1, 1),
('202', 2, 2, 0, 1),
('301', 3, 8, 1, 1),
('302', 3, 4, 0, 1);

go

insert into RoomAvailability (RoomID, AvailableDate, AvailableStartTime, AvailableEndTime, AvailableStatus) values
--use updated dates and through the school year, August to May
--Time increments in 15 minutes
(1, '2026-09-25', '09:00:00', '9:15:00', 1),
(1, '2026-09-25', '13:00:00', '13:15:00', 1),
(2, '2026-09-26', '08:15:00', '8:30:00', 1),
(3, '2026-09-26', '14:15:00', '14:30:00', 1),
(4, '2026-09-27', '09:30:00', '9:45:00', 1),
(5, '2026-09-28', '13:00:00', '13:15:00', 1),
(6, '2026-09-28', '10:30:00', '10:45:00', 1);

go

insert into AppUser (UserEmail, UserPassword) values
('jak00049@mix.wvu.edu', 'password1'),
('cc00117@mix.wvu.edu', 'password2'),
('srh00041@mix.wvu.edu', 'password3');

go

insert into RoomReservation (RoomAvailabilityID, ReservationDate, ReservationStartTime, ReservationEndTime, ReservedByUser) values
(1, '2026-09-25', '09:00:00', '9:15:00', 1),
(2, '2026-09-25', '13:00:00', '13:15:00', 2),
(3, '2026-09-26', '08:15:00', '8:30:00', 3),
(4, '2026-09-26', '14:15:00', '14:30:00', 1),
(5, '2026-09-27', '09:30:00', '9:45:00', 2),
(6, '2026-09-28', '13:00:00', '13:15:00', 3),
(7, '2026-09-28', '10:30:00', '10:45:00', 1);

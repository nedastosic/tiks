USE [SkiPass]
GO

/****** Object:  View [dbo].[Daily_rentals]    Script Date: 5.9.2020. 13:40:58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Daily_rentals]
AS
    select  year(RentalDate)	AS year,
			month(RentalDate)	AS month,
			day(RentalDate)		AS day,
			count(*)			AS total
	from Rental
	group by RentalDate;
GO

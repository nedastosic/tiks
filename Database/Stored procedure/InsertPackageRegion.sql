-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Inser package
-- =============================================
ALTER PROCEDURE [dbo].[InsertPackageRegion]
	@PackageID BIGINT,
	@RegionID BIGINT
AS
BEGIN
	
	INSERT INTO PackageRegion(PackageID, RegionID, CreationDate)
	VALUES (@PackageID, @RegionID, GETDATE())

	SELECT 0 AS Greska,'Uspesno obavljeno.' as Poruka
END
GO

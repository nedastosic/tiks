-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Inser package
-- =============================================
ALTER PROCEDURE [dbo].[InsertPackage]
	@PackageName NVARCHAR(100)
AS
BEGIN
DECLARE @PackageID  BIGINT

SELECT @PackageID = MAX(Package.PackageID)+1
FROM Package
	
	IF EXISTS (
		SELECT *
		FROM Package
		WHERE Package.Name = @PackageName
	)
	BEGIN
		SELECT  1 AS Greska,'Vec postoji paket sa istim nazivom.' AS Poruka
		RETURN
	END

	INSERT INTO Package(PackageID,[Name])
	VALUES (@PackageID, @PackageName)

	SELECT @PackageID AS ID

END
GO

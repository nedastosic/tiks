-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Description:	
-- =============================================
ALTER PROCEDURE [dbo].[SQLTest_SelectPackageRegion] 
AS
BEGIN
DECLARE @PackageID BIGINT
SET @PackageID = 1

CREATE TABLE #ActualResult(PackageName NVARCHAR(50), RegionName NVARCHAR(50))

INSERT INTO #ActualResult
	SELECT	Package.Name, Region.Name
	FROM	Package
			INNER JOIN PackageRegion
				ON Package.PackageID = PackageRegion.PackageID
			INNER JOIN Region
				ON PackageRegion.RegionID = Region.RegionID
	WHERE Package.PackageID = @PackageID
	EXEC TST.Assert.IsTableNotEmpty 'Paket mora sadrzati regije.'
DROP TABLE #ActualResult
END
GO

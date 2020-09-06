-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Delete region from package
-- =============================================
ALTER PROCEDURE [dbo].[DeleteRegionFromPackage]
	@PackageID BIGINT,
	@RegionID BIGINT
AS
BEGIN
	DELETE PackageRegion
	WHERE PackageID = @PackageID AND RegionID = @RegionID
END
GO

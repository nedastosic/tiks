
-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Update package
-- =============================================
ALTER PROCEDURE [dbo].[UpdatePackage]
	@PackageID BIGINT,
	@Name NVARCHAR(100)
AS
BEGIN

	UPDATE Package
	SET [Name] = @Name
	WHERE PackageID = @PackageID
END
GO

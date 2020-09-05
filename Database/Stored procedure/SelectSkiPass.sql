-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Select ski pass by id
-- =============================================
ALTER PROCEDURE [dbo].[SelectSkiPass] 
	@SkiPassID BIGINT
AS
BEGIN
	
	SELECT SkiPass.*
	FROM SkiPass
	WHERE	SkiPassID = @SkiPassID

END
GO

USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[SelectRegion]    Script Date: 06.09.2020. 14:48:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Select regions
-- =============================================
ALTER PROCEDURE [dbo].[SelectRegions] 
AS
BEGIN
	SELECT Region.*
	FROM Region

END

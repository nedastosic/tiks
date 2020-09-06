USE [SkiPass]
GO
/****** Object:  StoredProcedure [dbo].[SelectRegion]    Script Date: 06.09.2020. 14:49:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Slobodanka Tesmanovic
-- Create date: 01.09.2020.
-- Description:	Select region by packageID
-- =============================================
CREATE PROCEDURE [dbo].[SelectRegion] 
AS
BEGIN
	SELECT Region.*
	FROM Region

END

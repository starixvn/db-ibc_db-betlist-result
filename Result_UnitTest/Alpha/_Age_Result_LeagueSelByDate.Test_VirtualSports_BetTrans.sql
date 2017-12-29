/*<info serverAlias="DBAGETEST-UnitTest_Kos" executers="vnteam" viewers="vnteam" isFunction="0" isNested="0"></info>*/

USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_Result_LeagueSelByDate].[Test_VirtualSports_BetTrans]    Script Date: 1/13/2017 1:17:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_Result_LeagueSelByDate].[Test_VirtualSports_BetTrans]
AS

/*
	Created: Kos@20180116
	Task: Unit Test
	DB: DBEXT.UnitTest_Kos

	Revisions:
		- 20180116@Kos: Create new [#Redmine: 89580]
*/

BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		LeagueName	NVARCHAR(1000),
		LeagueId	INT,
		EventDate	DATETIME,
		SportType	SMALLINT
	)

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay
	FROM @tmp

	DECLARE @EventDate	DATETIME,
		@SportType		TINYINT,
		@LeagueId		INT

	SELECT TOP(1)
		@EventDate = o.eventdate,
		@SportType = r.sporttype,
		@LeagueId = r.leagueid
	FROM bodb02.dbo.VSRaceInfo AS r WITH (NOLOCK)
		INNER JOIN bodb02.dbo.VSOutright AS o WITH (NOLOCK) ON r.EventID = o.EventID
	WHERE r.SportType IN (181, 182, 183, 184, 185)
		AND r.EventStatus ='completed'

	IF @SportType IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Age_Result_LeagueSelByDate]
							@EventDate = ''' + CONVERT(VARCHAR(10), @EventDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR(10), @MoveBetsDay, 23) + ''',
							@SportType = ' + CONVERT(VARCHAR(3), @SportType) + ',
							@IsShowAll = 1'

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command;

		DECLARE @Actual	INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE LeagueId = @LeagueId

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = 1,
			@Actual = @Actual,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO

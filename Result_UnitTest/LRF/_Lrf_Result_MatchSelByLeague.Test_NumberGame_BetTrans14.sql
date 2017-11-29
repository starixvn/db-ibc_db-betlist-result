USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_Result_MatchSelByLeague].[Test_NumberGame_BetTrans14]    Script Date: 1/13/2017 2:09:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_Result_MatchSelByLeague].[Test_NumberGame_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		SportType		TINYINT,
		BetStatus		NVARCHAR(50),
		LeagueId		INT,
		MatchId			INT,
		Lcolor			NVARCHAR(50),
		MatchCode		NVARCHAR(50),
		EventDate		DATETIME,
		KickOffTime		DATETIME,
		HomeId			INT,
		AwayId			INT,
		HtHomeScore		INT,
		HtAwayScore		INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		EventStatus		NVARCHAR(50),
		ShowTime		NVARCHAR(50),
		HomeId2			INT,
		IsNeutral		BIT,
		GoalRecord		VARCHAR(50),
		IsHTCal			BIT,
		Calculate		BIT,
		IsPending		BIT
	)

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay, 
		@BalanceUpDay = BalanceUpDay
	FROM @tmp

	DECLARE @EventDate	DATETIME,
		@SportType		TINYINT,
		@LeagueId		INT,
		@MatchId		INT

	SELECT TOP(1)
		@EventDate = m.eventdate,
		@SportType = m.sporttype,
		@LeagueId = m.leagueid,
		@MatchId = m.matchid
	FROM bodb02.dbo.match14 AS m WITH (NOLOCK)
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH(NOLOCK) ON m.sporttype = s.SportType
	WHERE s.ProductID = 3
		AND m.eventstatus NOT IN ('closed', 'running')

	IF @SportType IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_Result_MatchSelByLeague]
							@FromDate = ''' + CONVERT(VARCHAR, @EventDate, 23) + ''',
							@MoveBetsDay = ''' + CONVERT(VARCHAR, @MoveBetsDay, 23) + ''',
							@LeagueId = ' + CONVERT(VARCHAR(10), @LeagueId) + ',
							@SportType = ' + CONVERT(VARCHAR(5), @SportType) + ',
							@IsShowAll = 1'

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Actual	INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE MatchId = @MatchId

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

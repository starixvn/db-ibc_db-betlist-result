USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_Result_LeagueSelByDate].[Test_HorseRacing_BetTrans]    Script Date: 1/13/2017 1:03:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_Result_LeagueSelByDate].[Test_HorseRacing_BetTrans]
AS
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
		@SportType = l.sporttype,
		@LeagueId = l.leagueid
	FROM bodb02.dbo.league AS l WITH (NOLOCK)
		INNER JOIN bodb02.dbo.outright AS o WITH (NOLOCK) ON l.leagueid = o.leagueid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH(NOLOCK) ON l.sporttype = s.SportType
	WHERE s.ProductID = 2
		AND o.oddsstatus ='completed'

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

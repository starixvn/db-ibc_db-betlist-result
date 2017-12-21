USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_BetList_SelMatchResult].[Test_HorseRacing_BetTrans14]    Script Date: 1/13/2017 12:54:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_BetList_SelMatchResult].[Test_HorseRacing_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		MatchCode	VARCHAR(10),
		RaceName	INT,
		Place		TINYINT,
		SportType	INT,
		HorseId		INT,
		Odds		SMALLMONEY,
		PlaceOdds	SMALLMONEY,
		MeetingId	INT,
		Status		VARCHAR(10),
		IsFavor		BIT,
		IsSCR		BIT,
		FOddsStatus	VARCHAR(10)
	)

	DECLARE @MatchId	INT,
		@BetType		SMALLINT = 31,
		@RaceNo			VARCHAR(50),
		@LeagueId		INT,
		@EventDate		DATETIME

	SELECT TOP(1)
		@MatchId = o.orid,
		@RaceNo = o.groupmatch,
		@LeagueId = o.leagueid,
		@EventDate = o.eventdate
	FROM bodb02.dbo.outright14 AS o WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON o.leagueid = l.leagueid
	WHERE o.oddsstatus = 'completed'
		AND o.groupmatch IS NOT NULL

	IF @MatchId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Age_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@RaceNo = ''' + @RaceNo + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command;

		DECLARE @Actual	INT,
			@Expected	INT

		SELECT @Actual = COUNT(*)
		FROM bodb02.dbo.outright14 AS o WITH (NOLOCK)
			INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON o.leagueid = l.leagueid
		WHERE o.leagueid = @LeagueId
			AND o.groupmatch = @RaceNo
			AND o.eventdate = @EventDate
			AND (ISNULL(o.placing, 0) <> 0 OR o.IsSCR = 1)

		SELECT @Expected = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals
			@Actual = @Actual,
			@Expected = @Expected,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO

USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelMatchResult].[Test_Sportsbook_BetTrans_Normal]    Script Date: 12/1/2017 10:19:20 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelMatchResult].[Test_Sportsbook_BetTrans_Normal]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		SportType		INT,
		BetStatus		NVARCHAR(50),
		HtHomeScore		INT,
		HtAwaycore		INT,
		PlayTime		DATETIME,
		LeagueId		INT,
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		MatchCode		NVARCHAR(50),
		KickOffTime		DATETIME,
		EventDate		DATETIME,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		EventStatus		NVARCHAR(50),
		IsRefund		BIT,
		IsCalRefund		BIT,
		IsNeutral		BIT,
		GoalRecord		VARCHAR(50),
		IsHTCal			BIT,
		Calculate		BIT,
		IsPending		BIT,
		ShowTime		NVARCHAR(50),
		HomeId2			INT
	)

	DECLARE @MatchId	INT,
		@BetType		SMALLINT = 1

	SELECT TOP(1)
		@MatchId = m.matchid
	FROM bodb02.dbo.match AS m WITH (NOLOCK)
	WHERE m.eventstatus NOT IN ('closed', 'running')
		AND m.sporttype BETWEEN 1 AND 99

	IF @MatchId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR(5), @BetType)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Actual	INT,
			@Expected	INT

		SELECT @Expected = COUNT(*)
		FROM bodb02.dbo.match AS m WITH(NOLOCK)
			LEFT OUTER JOIN bodb02.dbo.match_remark AS mr WITH(NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb02.dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'
		WHERE m.matchid = @MatchId

		SELECT @Actual = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals 
			@Expected = @Expected,
			@Actual = @Actual,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;

GO

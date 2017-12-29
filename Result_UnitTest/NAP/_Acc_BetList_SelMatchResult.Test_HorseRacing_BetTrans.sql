/*<info serverAlias="DBAGETEST-UnitTest_Kos" executers="vnteam" viewers="vnteam" isFunction="0" isNested="0"></info>*/

USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetList_SelMatchResult].[Test_HorseRacing_BetTrans]    Script Date: 1/13/2017 11:17:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetList_SelMatchResult].[Test_HorseRacing_BetTrans]
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
		MatchCode	VARCHAR(10),
		Placing		TINYINT,
		SportType	INT,
		Runner		INT,
		LeagueId	INT,
		EventTime	NVARCHAR(50),
		HorseNo		NVARCHAR(50),
		WinOdds		NVARCHAR(50),
		PlaceOdds	NVARCHAR(50),
		IsFavor		NVARCHAR(50)
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
	FROM bodb02.dbo.outright AS o WITH (NOLOCK)
		INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON o.leagueid = l.leagueid
	WHERE o.oddsstatus = 'completed'
		AND o.groupmatch IS NOT NULL

	IF @MatchId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetList_SelMatchResult]
							@MatchId = ' + CONVERT(VARCHAR(10), @MatchId) + ',
							@BetType = ' + CONVERT(VARCHAR(5), @BetType) + ',
							@RaceNo = ''' + @RaceNo + ''''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter
			@ResultsetNo = 1,
			@Command = @Command;

		DECLARE @Actual	INT,
			@Expected	INT

		SELECT @Expected = COUNT(*)
		FROM bodb02.dbo.outright AS o WITH (NOLOCK)
			INNER JOIN bodb02.dbo.league AS l WITH(NOLOCK) ON o.leagueid = l.leagueid
		WHERE o.leagueid = @LeagueId
			AND o.groupmatch = @RaceNo
			AND o.eventdate = @EventDate
			AND ISNULL(o.placing, 0) <> 0

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

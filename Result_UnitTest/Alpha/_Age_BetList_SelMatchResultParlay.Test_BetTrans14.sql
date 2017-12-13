USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_BetList_SelMatchResultParlay].[Test_BetTrans14]    Script Date: 12/14/2017 5:00:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_BetList_SelMatchResultParlay].[Test_BetTrans14]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		SportType		INT,
		LeagueId		INT,
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		HtHomeScore		INT,
		HtAwayScore		INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		KickOffTime		DATETIME,
		EventDate		DATETIME,
		IsNeutral		BIT,
		BetStatus		VARCHAR(50),
		EventStatus		VARCHAR(15),
		IsRefund		BIT,
		IsCalRefund		BIT,
		GoalRecord		VARCHAR(50),
		MatchCode		VARCHAR(50),
		IsHTCal			BIT,
		Calculate		BIT,
		IsPending		BIT, 
		BetType			SMALLINT,
		BetCheck		VARCHAR(50)
	)

	DECLARE @RefNo	BIGINT

	SELECT TOP(1)
		@RefNo = b.refno
	FROM bodb02.dbo.bettransm14 AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH(NOLOCK) ON b.bettype = s.bettype
	WHERE s.ProductID = 1

	IF @RefNo IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Age_BetList_SelMatchResultParlay]
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 
			@ResultsetNo = 1,
			@Command = @Command;

		DECLARE @Actual	INT,
			@Expected	INT

		SELECT @Expected = COUNT(*)
		FROM
			( SELECT DISTINCT
					bm.matchid,
					bm.bettype,
					bm.betcheck
				FROM bodb02.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN bodb02.dbo.SportBettypeMatrix AS s ON bm.bettype = s.Bettype
				WHERE bm.refno = @RefNo AND s.ProductID = 1) AS bm
			INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN bodb02.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb02.dbo.ResultDetail AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'

		SELECT @Expected = @Expected + COUNT(*)
		FROM
			( SELECT DISTINCT
					bm.matchid,
					bm.bettype,
					bm.betcheck
				FROM bodb02.dbo.bettransm14 AS bm WITH (NOLOCK)
					INNER JOIN bodb02.dbo.SportBettypeMatrix AS s ON bm.bettype = s.Bettype
				WHERE bm.refno = @RefNo AND s.ProductID = 1) AS bm
			INNER JOIN bodb02.dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN bodb02.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN bodb02.dbo.ResultDetail14 AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'

		SELECT @Expected = @Expected + COUNT(*)
		FROM
			( SELECT DISTINCT
					bm.matchid,
					bm.bettype,
					bm.betcheck
				FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN bodb02.dbo.SportBettypeMatrix AS s ON bm.bettype = s.Bettype
				WHERE bm.refno = @RefNo AND s.ProductID = 1) AS bm
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
			LEFT OUTER JOIN bodb02.dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
			LEFT JOIN DBARC.bodb_Archive.dbo.ResultDetail_bk AS d WITH (NOLOCK) ON d.matchID = m.matchid AND d.ResourceId = '00'

		SELECT @Actual = COUNT(*)
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

USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_BetList_SelRunningByDate_Mem].[Test_Sportsbook_BetTrans_Normal_GetAll]    Script Date: 1/11/2017 11:02:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_BetList_SelRunningByDate_Mem].[Test_Sportsbook_BetTrans_Normal_GetAll]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		SportType		SMALLINT,
		Username		NVARCHAR(30),
		BetType			SMALLINT,
		LeagueId		INT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetID			BIGINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(20),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		ADiscount		SMALLMONEY,
		MDiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		IsNeutral		BIT,
		OddsType		TINYINT,
		ShowTime		NVARCHAR(50),
		ComStatus		NVARCHAR(20),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		OddsSpread		SMALLMONEY
	)

	DECLARE @TransId	BIGINT,
		@CustId			INT,
		@MatchId		INT,
		@GetAll			BIT			= 1

	SELECT TOP 1 @MatchId = m.matchid
	FROM bodb02.dbo.match AS m WITH (NOLOCK)
	WHERE EXISTS (	SELECT 1 FROM bodb_Age.dbo.bettrans_running AS b WITH (NOLOCK)
						INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
					WHERE b.matchid = m.matchid
						AND s.ProductID = 1
						AND s.EventType = 1)

	SELECT TOP 1
		@TransId = b.transid,
		@CustId = b.custid
	FROM bodb_Age.dbo.bettrans_running AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE b.statusID IN (0, 1)
		AND b.matchid = @MatchId
		AND s.ProductID = 1
		AND s.EventType = 1

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb_Age.dbo.[Age_BetList_SelRunningByDate_Mem]
							@CustId = ' + CONVERT(VARCHAR, @CustId) + ',
							@GetAll = ' + CONVERT(VARCHAR, @GetAll) + ',
							@ShowSB = 1'

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Expected INT

		SELECT @Expected = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

		-- Assert
		EXEC tSQLt.AssertEquals @Expected, 1, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END

END;

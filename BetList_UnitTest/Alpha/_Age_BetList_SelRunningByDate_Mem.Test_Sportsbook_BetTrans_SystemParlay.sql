USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_BetList_SelRunningByDate_Mem].[Test_Sportsbook_BetTrans_SystemParlay]    Script Date: 1/11/2017 11:17:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_BetList_SelRunningByDate_Mem].[Test_Sportsbook_BetTrans_SystemParlay]
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
		@TransDate		DATETIME,
		@GetAll			BIT			= 0

	SELECT TOP 1
		@TransId = b.transid,
		@CustId = b.custid,
		@TransDate = b.transdate
	FROM bodb_Age.dbo.bettrans_running AS b WITH (NOLOCK)
	WHERE b.bettype = 29
		AND b.statusID IN (0, 1)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb_Age.dbo.[Age_BetList_SelRunningByDate_Mem]
							@CustId = ' + CONVERT(VARCHAR, @CustId) + ',
							@GetAll = ' + CONVERT(VARCHAR, @GetAll) + ',
							@FromDate = ''' + CONVERT(VARCHAR, DATEADD(DAY, DATEDIFF(DAY, 0, @TransDate), 0), 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, DATEADD(DAY, DATEDIFF(DAY, -1, @TransDate), 0), 23) + ''',
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

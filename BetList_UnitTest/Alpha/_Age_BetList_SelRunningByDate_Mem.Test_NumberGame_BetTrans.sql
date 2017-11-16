USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_BetList_SelRunningByDate_Mem].[Test_NumberGame_BetTrans]    Script Date: 1/11/2017 10:55:24 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_BetList_SelRunningByDate_Mem].[Test_NumberGame_BetTrans]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		SportType		SMALLINT,
		CustId			INT,
		Username		NVARCHAR(50),
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
		OddsSpread		SMALLMONEY,
		Currency		NVARCHAR(50)
	)

	DECLARE @TransId	BIGINT,
		@CustId			INT,
		@TransDate		DATETIME,
		@GetAll			BIT			= 0

	SELECT TOP(1)
		@TransId = b.transid,
		@CustId = b.custid,
		@TransDate = b.transdate
	FROM bodb_Age.dbo.bettrans_running AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE s.ProductID = 3
		AND b.statusID IN (0, 1)

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb_Age.dbo.[Age_BetList_SelRunningByDate_Mem]
							@CustId = ' + CONVERT(VARCHAR(10), @CustId) + ',
							@GetAll = ' + CONVERT(VARCHAR(1), @GetAll) + ',
							@FromDate = ''' + CONVERT(VARCHAR, DATEADD(DAY, DATEDIFF(DAY, 0, @TransDate), 0), 23) + ''',
							@ToDate = ''' + CONVERT(VARCHAR, DATEADD(DAY, DATEDIFF(DAY, -1, @TransDate), 0), 23) + ''',
							@ProductIDs = ''3'''

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Actual INT

		SELECT @Actual = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

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

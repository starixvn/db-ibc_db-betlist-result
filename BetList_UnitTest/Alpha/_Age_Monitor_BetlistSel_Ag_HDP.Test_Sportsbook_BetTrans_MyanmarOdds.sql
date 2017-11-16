USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_Monitor_BetlistSel_Ag_HDP].[Test_Sportsbook_BetTrans_MyanmarOdds]    Script Date: 1/10/2017 10:20:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_Monitor_BetlistSel_Ag_HDP].[Test_Sportsbook_BetTrans_MyanmarOdds]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		SportType			SMALLINT,
		MatchId				INT,
		LeagueId			INT,
		Username			NVARCHAR(50),
		BetType				INT,
		TransId				BIGINT,
		RefNo				NVARCHAR(50),
		TransDate			DATETIME,
		MatchCode			NVARCHAR(50),
		HomeId				INT,
		AwayId				INT,
		Race				NVARCHAR(20),
		BetId				BIGINT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LiveIndicator		BIT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Stake				MONEY,
		Status				NVARCHAR(50),
		BetTeam				NVARCHAR(50),
		Ip					NVARCHAR(15),
		IsNeutral			BIT,
		OddsType			TINYINT,
		OddsSpread			SMALLMONEY
	)

	DECLARE @TransId	BIGINT,
		@CustId			INT

	SELECT TOP(1)
		@TransId = b.transid,
		@CustId = ci.recommend
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.custInfo AS ci WITH (NOLOCK) ON b.custid = ci.custid
	WHERE b.bettype IN (301, 303)
		AND b.statusID IN (0, 1)
	ORDER BY b.transid DESC

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Age_Monitor_BetlistSel_Ag_HDP]
							@CustId = ' + CONVERT(VARCHAR(10), @CustId) + ',
							@TransId = ' + CONVERT(VARCHAR(20), @TransId - 1) + ''

		INSERT @Data
		EXEC sp_executesql @Command

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

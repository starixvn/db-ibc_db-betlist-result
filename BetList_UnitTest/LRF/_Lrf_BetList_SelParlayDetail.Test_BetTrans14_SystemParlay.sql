USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelParlayDetail].[Test_BetTrans14_MixParlay]    Script Date: 1/11/2017 1:12:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelParlayDetail].[Test_BetTrans14_SystemParlay]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		TransId			BIGINT,
		BetId			TINYINT,
		BetCheck		VARCHAR(100),
		SportType		INT,
		LeagueId		INT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
		MatchId			INT,
		ShowTime		NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			FLOAT,
		Hdp2			FLOAT,
		Odds			MONEY,
		BetTeam			NVARCHAR(50),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		StatusId		INT,
		TransDesc		NVARCHAR(200)
	)

	DECLARE @SubTicket TABLE (
		TransId	BIGINT
	)

	DECLARE @tmp TABLE (BalanceUpDay SMALLDATETIME, MoveBetsDay SMALLDATETIME) 

	INSERT INTO @tmp(BalanceUpDay, MoveBetsDay)
	EXEC bodb02.dbo.Age_SelBalanceUpDay

	DECLARE @MoveBetsDay SMALLDATETIME,
		@BalanceUpDay SMALLDATETIME

	SELECT @MoveBetsDay = MoveBetsDay, 
		@BalanceUpDay = BalanceUpDay
	FROM @tmp

	IF @BalanceUpDay IS NULL
		SET @BalanceUpDay = @MoveBetsDay

	DECLARE @TransId			BIGINT,
		@RefNo					BIGINT,
		@ExpectedNumOfSubTicket	TINYINT

	SELECT TOP(1)
		@TransId = b.transid,
		@RefNo = b.refno
	FROM bodb02.dbo.bettrans14 AS b WITH (NOLOCK)
	WHERE b.bettype = 29
		AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

	INSERT INTO @SubTicket
	SELECT b.transid
	FROM bodb02.dbo.bettransm AS b WITH (NOLOCK)
	WHERE b.refno = @RefNo

	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		INSERT INTO @SubTicket
		SELECT b.transid
		FROM bodb02.dbo.bettransm14 AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

	IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		INSERT INTO @SubTicket
		SELECT b.transid
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

	SELECT @ExpectedNumOfSubTicket = COUNT(DISTINCT TransId)
	FROM @SubTicket

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Lrf_BetList_SelParlayDetail] 
							@TransId = ' + CONVERT(VARCHAR(20), @TransId)

		INSERT @Data
		EXEC sp_executesql @Command

		DECLARE @NumOfSubTicket	TINYINT

		SELECT @NumOfSubTicket = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals
			@Expected = @ExpectedNumOfSubTicket,
			@Actual = @NumOfSubTicket,
			@Message = @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail @Message0 = 'No available test data'
	END
END;


GO

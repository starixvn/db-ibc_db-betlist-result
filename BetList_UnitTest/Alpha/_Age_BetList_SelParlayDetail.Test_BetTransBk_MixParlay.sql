USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Age_BetList_SelParlayDetail].[Test_BetTransBk_MixParlay]    Script Date: 1/10/2017 10:16:57 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Age_BetList_SelParlayDetail].[Test_BetTransBk_MixParlay]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		TransId			BIGINT,
		SportType		SMALLINT,
		LeagueId		INT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
		MatchId			INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		BetTeam			NVARCHAR(20),
		StatusId		INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	BIT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(200)
	)

	DECLARE @TransId			BIGINT,
		@RefNo					BIGINT,
		@ExpectedNumOfSubTicket	TINYINT

	SELECT TOP 1
		@TransId = b.transid,
		@RefNo = b.refno
	FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
	WHERE b.bettype = 9

	SELECT @ExpectedNumOfSubTicket = COUNT(*)
	FROM bodb02.dbo.bettransm AS b WITH (NOLOCK)
	WHERE b.refno = @RefNo

	IF EXISTS(SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		SELECT @ExpectedNumOfSubTicket = COUNT(*) + @ExpectedNumOfSubTicket
		FROM bodb02.dbo.bettransm14 AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

	IF EXISTS(SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		SELECT @ExpectedNumOfSubTicket = COUNT(*) + @ExpectedNumOfSubTicket
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Age_BetList_SelParlayDetail] 
							@TransId = ' + CONVERT(VARCHAR, @TransId)

		INSERT @Data
		EXEC sp_executesql @Command

		DECLARE @NumOfSubTicket	TINYINT

		SELECT @NumOfSubTicket = COUNT(*)
		FROM @Data

		-- Assert
		EXEC tSQLt.AssertEquals @ExpectedNumOfSubTicket, @NumOfSubTicket, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END

END;

USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Lrf_BetList_SelParlayDetail].[Test_BetTrans_MixParlay]    Script Date: 1/11/2017 1:11:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Lrf_BetList_SelParlayDetail].[Test_BetTrans_MixParlay]
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

	DECLARE @TransId			BIGINT,
		@RefNo					BIGINT,
		@ExpectedNumOfSubTicket	TINYINT

	SELECT TOP(1)
		@TransId = b.transid,
		@RefNo = b.refno
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.bettype = 9

	SELECT @ExpectedNumOfSubTicket = COUNT(*)
	FROM bodb02.dbo.bettransm AS b WITH (NOLOCK)
	WHERE b.refno = @RefNo

	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		SELECT @ExpectedNumOfSubTicket = COUNT(*) + @ExpectedNumOfSubTicket
		FROM bodb02.dbo.bettransm14 AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

	IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		SELECT @ExpectedNumOfSubTicket = COUNT(*) + @ExpectedNumOfSubTicket
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

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

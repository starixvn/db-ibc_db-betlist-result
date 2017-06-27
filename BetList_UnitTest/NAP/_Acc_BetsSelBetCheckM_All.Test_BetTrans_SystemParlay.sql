USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetsSelBetCheckM_All].[Test_BetTrans_SystemParlay]    Script Date: 8/2/2016 1:50:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetsSelBetCheckM_All].[Test_BetTrans_SystemParlay]
AS
BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		TransId			BIGINT,
		BetType			INT,
		Stake			MONEY,
		Currency		NVARCHAR(50),
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
		LeagueId		INT,
		SportType		SMALLINT,
		IsNeutral		BIT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(200)
	)

	DECLARE @TempData TABLE (
		TransId	BIGINT
	)

	DECLARE @TransId	BIGINT,
		@RefNo			BIGINT

	SELECT TOP(1)
		@TransId = b.transid,
		@RefNo = b.refno
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.bettype = 29

	INSERT INTO @TempData
	SELECT b.transid
	FROM bodb02.dbo.bettransm AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
	WHERE b.refno = @RefNo

	IF EXISTS (SELECT 1 FROM bodb02.dbo.bettransm14 WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		INSERT INTO @TempData
		SELECT b.transid
		FROM bodb02.dbo.bettransm14 AS b WITH (NOLOCK)
			INNER JOIN bodb02.dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo
	END

	IF EXISTS (SELECT 1 FROM DBARC.bodb_Archive.dbo.bettransm WITH (NOLOCK) WHERE refno = @RefNo)
	BEGIN
		INSERT INTO @TempData
		SELECT b.transid
		FROM DBARC.bodb_Archive.dbo.bettransm AS b WITH (NOLOCK)
			INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.refno = @RefNo
	END

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetsSelBetCheckM_All] 
							@TransId = ' + CONVERT(VARCHAR, @TransId) + ',
							@RefNo = ' + CONVERT(VARCHAR, @RefNo)

		INSERT @Data
		EXEC sp_executesql @Command

		DECLARE @NumOfSubTicket		TINYINT,
			@ExpectedNumOfSubTicket	TINYINT

		SELECT @NumOfSubTicket = COUNT(*)
		FROM @Data

		SELECT @ExpectedNumOfSubTicket = COUNT(DISTINCT TransId)
		FROM @TempData

		-- Assert
		EXEC tSQLt.AssertEquals @ExpectedNumOfSubTicket, @NumOfSubTicket, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END
END;

GO


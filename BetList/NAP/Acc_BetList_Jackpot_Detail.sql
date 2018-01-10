USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_BetList_Jackpot_Detail]
	@TransId	BIGINT,
	@CustId		INT,
	@BetType	SMALLINT
AS

/*
	Created: Kos@20151012
	Task: Get Jackpot Won ticket detail
	DB: DBACC.bodb02
	Original:
	Revisions:
		- 20180207@Kos: Support ONERnG Jackpot [#Redmine: 88652]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	-- Support RNG Casino Single Wallet
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID = 6 AND SubProduct <> ''

	-- Create temp table
	DECLARE @Data TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		SportType		INT,
		BetType			INT,
		Odds			MONEY,
		Status			NVARCHAR(10),
		StatusId		TINYINT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Commission		MONEY,
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		Discount		DECIMAL(9, 8),
		ADiscount		DECIMAL(9, 8),
		SDiscount		DECIMAL(9, 8),
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		Ip				NVARCHAR(15),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT
	)

	-- Get ticket
	IF EXISTS ( SELECT TOP(1) 1
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
				WHERE b.transid = @TransId AND b.custid = @CustId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.transid,
			b.RefNo,
			b.transdate,
			b.winlostdate,
			b.productID AS SportType,
			b.gameID AS BetType,
			0 AS Odds,
			b.status,
			b.statusID,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS commission,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.discount,
			b.adiscount,
			b.sdiscount,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.ip,
			CASE
				WHEN sbt.productID = 6 THEN b.TranId3rd
				ELSE ''
			END AS BetCheck,
			b.transdesc,
			CASE
				WHEN sbt.ProductID = 6 THEN ISNULL(b.RefNo2, -1)
				ELSE -1
			END AS BetdaqId
		FROM dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END
	ELSE IF EXISTS ( SELECT TOP(1) 1
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
					WHERE b.transid = @TransId AND b.custid = @CustId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.transid,
			b.RefNo,
			b.transdate,
			b.winlostdate,
			b.productID AS SportType,
			b.gameID AS BetType,
			0 AS Odds,
			b.status,
			b.statusID,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS commission,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.discount,
			b.adiscount,
			b.sdiscount,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.ip,
			CASE
				WHEN sbt.productID = 6 THEN b.TranId3rd
				ELSE ''
			END AS BetCheck,
			b.transdesc,
			CASE
				WHEN sbt.ProductID = 6 THEN ISNULL(b.RefNo2, -1)
				ELSE -1
			END AS BetdaqId
		FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END
	ELSE IF EXISTS ( SELECT TOP(1) 1
					FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
					WHERE b.transid = @TransId AND b.custid = @CustId )
	BEGIN
		INSERT INTO @Data
		SELECT
			b.transid,
			b.RefNo,
			b.transdate,
			b.winlostdate,
			b.productID AS SportType,
			b.gameID AS BetType,
			0 AS Odds,
			b.status,
			b.statusID,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			b.playercomm AS commission,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.discount,
			b.adiscount,
			b.sdiscount,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.ip,
			CASE
				WHEN sbt.productID = 6 THEN b.TranId3rd
				ELSE ''
			END AS BetCheck,
			b.transdesc,
			CASE
				WHEN sbt.ProductID = 6 THEN ISNULL(b.RefNo2, -1)
				ELSE -1
			END AS BetdaqId
		FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END

	SELECT * FROM @Data
END


GO
GRANT	VIEW DEFINITION	ON	Acc_BetList_Jackpot_Detail	TO	vnteam
GRANT	EXECUTE	ON	Acc_BetList_Jackpot_Detail	TO	bodbExtAccNet
GRANT	EXECUTE	ON	Acc_BetList_Jackpot_Detail	TO	bodbDownlineNetView
GRANT	EXECUTE	ON	Acc_BetList_Jackpot_Detail	TO	bodbDownlineNet
GRANT	EXECUTE	ON	Acc_BetList_Jackpot_Detail	TO	bodbAdminNet
GO

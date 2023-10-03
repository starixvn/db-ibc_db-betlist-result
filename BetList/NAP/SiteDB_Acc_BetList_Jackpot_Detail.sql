/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet,bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_Jackpot_Detail]
	@TransId	BIGINT,
	@CustId		INT,
	@BetType	SMALLINT,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: 20220727@Kos
	Task: NAP - Bet List - Get Jackpot Won ticket detail
	DB: DBSIG.bodb02
	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20230927@Razor: Support show max payout [Redmine: #194491]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	-- Support RNG Casino Single Wallet, PP, SG, Saba.club, VGaming
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE (ProductID IN (32, 36, 42, 66))
		OR (ProductID = 6 AND SubProduct <> '')

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
		Ip				VARCHAR(45),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
	)

	-- Get ticket
	IF EXISTS ( SELECT TOP(1) 1
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
				WHERE b.transid = @TransId AND b.custid = @CustId AND b.winlostdate > @MoveBetsDay)
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
			b.TranId3rd AS BetCheck,
			b.transdesc,
			ISNULL(b.RefNo2, -1) AS BetdaqId,
			b.ExtraInfo
		FROM dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END

	SELECT * FROM @Data
END
GO
/*<info serverAlias="DBACC-bodb02" executers="wsv_nap,wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_Jackpot_Detail]
	@TransId			BIGINT,
	@CustId				INT,
	@BetType			SMALLINT,
	@ExcludeBettrans	BIT				= 0,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME
AS

/*
	Created: Kos@20151012
	Task: Get Jackpot Won ticket detail
	DB: DBACC.bodb02
	Revisions:
		- 20180207@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20200709@Kos: Support PP Jackpot [Redmine: #137284]
		- 20210119@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #147709]
		- 20210429@Razor: Support VGaming [Redmine: #154047]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211115@Razor: Enhance to get Detail ticket [Redmine: #164614]
		- 20220124@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220808@Kos: Scale out DBTRANS [Redmine: #175253]
					- Add new input param @ExcludeBettrans BIT
		- 20230927@Razor: Support show max payout [Redmine: #194491]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20241218@Razor: Support Direct Member [Redmine: #211969]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250623@Benji: Support Playtech Live Jackpot[Redmine: #230127]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	-- Support RNG Casino Single Wallet, PP, SG, Saba.club, VGaming, Playtech RNG, Playtech Live
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500), Reftable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE SubProduct like 'Jackpot%'

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
		BetCheck		NVARCHAR(200),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
	)

	-- Get ticket
	IF @ExcludeBettrans = 0
	BEGIN
		IF EXISTS (SELECT TOP(1) 1
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
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				ELSE b.discount
			END,
			CASE
				WHEN b.mrecommend = -4 THEN 0
				ELSE b.adiscount
			END,
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
	ELSE IF EXISTS ( SELECT TOP(1) 1
					FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
					WHERE b.transid = @TransId AND b.custid = @CustId AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay)
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
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				ELSE b.discount
			END,
			CASE
				WHEN b.mrecommend = -4 THEN 0
				ELSE b.adiscount
			END,
			b.sdiscount,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			b.ip,
			b.TranId3rd AS BetCheck,
			b.transdesc,
			ISNULL(b.RefNo2, -1) AS BetdaqId,
			b.ExtraInfo
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
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				ELSE b.discount
			END,
			CASE
				WHEN b.mrecommend = -4 THEN 0
				ELSE b.adiscount
			END,
			b.sdiscount,
			(b.comm - b.playercomm) AS comm,
			(b.acomm - b.comm) AS acomm,
			(b.scomm - b.acomm) AS scomm,
			dp.IP,
			b.TranId3rd AS BetCheck,
			b.transdesc,
			ISNULL(b.RefNo2, -1) AS BetdaqId,
			b.ExtraInfo
		FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
			CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
		WHERE b.custid = @CustId AND b.transid = @TransId
	END
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
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
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
		IF EXISTS ( SELECT TOP(1) 1
			FROM dbo.bettransLC AS b WITH (NOLOCK)
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
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
					END,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
					END,
				b.sdiscount,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm,
				(b.scomm - b.acomm) AS scomm,
				b.ip,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				ISNULL(b.RefNo2, -1) AS BetdaqId,
				b.ExtraInfo
				FROM dbo.bettransLC AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
				WHERE b.custid = @CustId AND b.transid = @TransId
		END
		
		ELSE IF EXISTS ( SELECT TOP(1) 1
						FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
							INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
						WHERE b.transid = @TransId AND b.custid = @CustId AND b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay)
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
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				b.sdiscount,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm,
				(b.scomm - b.acomm) AS scomm,
				b.ip,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				ISNULL(b.RefNo2, -1) AS BetdaqId,
				b.ExtraInfo
			FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
			WHERE b.custid = @CustId AND b.transid = @TransId
			END
		IF EXISTS ( SELECT TOP(1) 1
					FROM dbo.bettransLC14 AS b WITH (NOLOCK)
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
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				b.sdiscount,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm,
				(b.scomm - b.acomm) AS scomm,
				b.ip,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				ISNULL(b.RefNo2, -1) AS BetdaqId,
				b.ExtraInfo
			FROM dbo.bettransLC14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
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
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				b.sdiscount,
				(b.comm - b.playercomm) AS comm,
				(b.acomm - b.comm) AS acomm,
				(b.scomm - b.acomm) AS scomm,
				dp.IP,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				ISNULL(b.RefNo2, -1) AS BetdaqId,
				b.ExtraInfo
			FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
				INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.Bettype
			WHERE b.custid = @CustId AND b.transid = @TransId
			END
		IF EXISTS ( SELECT TOP(1) 1
			FROM bodb_Archive.dbo.bettransRnG_bk AS b WITH (NOLOCK)
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
            CASE
                WHEN b.recommend IN (-3, -4) THEN 0
                ELSE b.discount
            END,
            CASE
                WHEN b.mrecommend = -4 THEN 0
                ELSE b.adiscount
            END,
            b.sdiscount,
            (b.comm - b.playercomm) AS comm,
            (b.acomm - b.comm) AS acomm,
            (b.scomm - b.acomm) AS scomm,
            b.ip,
            b.TranId3rd AS BetCheck,
            b.transdesc,
            ISNULL(b.RefNo2, -1) AS BetdaqId,
            b.ExtraInfo
        FROM bodb_Archive.dbo.bettransLC_bk AS b WITH (NOLOCK)
            INNER JOIN @SportBettype AS sbt ON b.gameID = sbt.BetType
        WHERE b.custid = @CustId AND b.transid = @TransId
    END
	END
	

	SELECT * FROM @Data
END
GO

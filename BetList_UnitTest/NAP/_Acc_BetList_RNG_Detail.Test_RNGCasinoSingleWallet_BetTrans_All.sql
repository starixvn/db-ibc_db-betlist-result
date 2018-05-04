/*<info serverAlias="DBAGETEST-UnitTest_Kos" executers="vnteam" viewers="vnteam" isFunction="0" isNested="0"></info>*/

USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetList_RNG_Detail].[Test_RNGCasinoSingleWallet_BetTrans_All]    Script Date: 8/2/2016 1:32:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetList_RNG_Detail].[Test_RNGCasinoSingleWallet_BetTrans_All]
AS

/*
	Created: Kos@20180116
	Task: Unit Test
	DB: DBEXT.UnitTest_Kos

	Revisions:
		- 20180116@Kos: Create new [#Redmine: 89580]
*/

BEGIN
	SET NOCOUNT ON

	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
		CustId			INT,
		TransId			BIGINT,
		SportType		INT,
		BetType			INT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		Status			NVARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Currency		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Commission		MONEY,
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SWinLost		MONEY,
		MWinLost		MONEY,
		AWinLost		MONEY,
		SDiscount		DECIMAL(9, 8),
		ADiscount		DECIMAL(9, 8),
		Discount		DECIMAL(9, 8),
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		Ip				NVARCHAR(15),
		TransDesc		NVARCHAR(300),
		BetCheck		NVARCHAR(50),
		MatchCode		VARCHAR(50),
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @RefNo	BIGINT,
		@CustID		INT,
		@TransType	TINYINT = 0,
		@TransId	BIGINT

	SELECT TOP(1)
		@RefNo = b.transid,
		@CustID = b.custid,
		@TransId = brng.transid
	FROM bodb02.dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb02.dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.refno = b.transid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 6 AND s.SubProduct <> ''

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetList_RNG_Detail]
							@RefNo = ' + CONVERT(VARCHAR(20), @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR(10), @CustID) + ',
							@TransType = ' + CONVERT(VARCHAR(2), @TransType)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 
			@ResultsetNo = 1,
			@Command = @Command;

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

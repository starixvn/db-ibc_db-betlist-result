USE [UnitTest_Kos]
GO
/****** Object:  StoredProcedure [_Acc_BetList_RNG_Detail].[Test_MacauGames_BetTransBk_All]    Script Date: 8/2/2016 1:29:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [_Acc_BetList_RNG_Detail].[Test_MacauGames_BetTransBk_All]
AS
BEGIN
	-- Arrange
	DECLARE @Data TABLE (
		RowNum			INT,
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
		MatchCode		VARCHAR(50)
	)

	DECLARE @RefNo	BIGINT,
		@CustID		INT,
		@TransType	TINYINT = 0,
		@TransId	BIGINT

	SELECT TOP 1
		@RefNo = b.transid,
		@CustID = b.custid,
		@TransId = brng.transid
	FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
		INNER JOIN DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK) ON brng.refno = b.transid
		INNER JOIN bodb02.dbo.SportBettypeMatrix AS s WITH (NOLOCK) ON b.bettype = s.BetType
	WHERE s.ProductID = 22

	IF @TransId IS NOT NULL
	BEGIN
		-- Act
		DECLARE @Command NVARCHAR(MAX)

		SET @Command = 'EXEC bodb02.dbo.[Acc_BetList_RNG_Detail]
							@RefNo = ' + CONVERT(VARCHAR, @RefNo) + ',
							@CustId = ' + CONVERT(VARCHAR, @CustID) + ',
							@TransType = ' + CONVERT(VARCHAR, @TransType)

		INSERT @Data
		EXEC tSQLt.ResultSetFilter 1, @Command;

		DECLARE @Expected INT

		SELECT @Expected = COUNT(*)
		FROM @Data
		WHERE TransId = @TransId

		-- Assert
		EXEC tSQLt.AssertEquals 1, @Expected, @Command
	END
	ELSE
	BEGIN
		EXEC tSQLt.Fail 'No available test data'
	END

END;

--@DB053
USE bodb_AGE
GO
CREATE TYPE [dbo].[TVP_SportBettypeMatrix] AS TABLE
(
	ProductID 		TINYINT
	, Bettype 		SMALLINT
	, EventType 	TINYINT
	, SubProduct 	VARCHAR(500)
)
GO

USE [bodb02]
GO
GRANT SELECT ON SportBettypeMatrix TO bodbDownlineNet;
GO
GRANT SELECT ON SportBettypeMatrix TO bodbDownlineNetView;
GO

CREATE TYPE [dbo].[TVP_BetTicketStatus] AS TABLE
(
	[StatusID] [TINYINT] NULL
)
GO

CREATE TYPE [dbo].[TVP_SportBettypeMatrix] AS TABLE
(
	ProductID 		TINYINT
	, Bettype 		SMALLINT
	, EventType 	TINYINT
	, SubProduct 	VARCHAR(500)
)
GO

CREATE TYPE [dbo].[TVP_TicketSportBettype] AS TABLE
(
	TransID			BIGINT
	, Refno			BIGINT
	, CustID 		INT 
	, ProductID 	TINYINT
	, Bettype 		SMALLINT	
	, EventType		TINYINT
	, WhTicket		TINYINT
)
GO

--@DB06
USE bodb_archive
GO

CREATE TYPE [dbo].[TVP_BetTicketStatus] AS TABLE
(
	[StatusID] [TINYINT] NULL
)
GO

CREATE TYPE [dbo].[TVP_SportBettypeMatrix] AS TABLE
(
	ProductID 		TINYINT
	, Bettype 		SMALLINT
	, EventType 	TINYINT
	, SubProduct 	VARCHAR(500)
)
GO

CREATE TYPE [dbo].[TVP_TicketSportBettype] AS TABLE
(
	TransID			BIGINT
	, Refno			BIGINT
	, CustID 		INT 
	, ProductID 	TINYINT
	, Bettype 		SMALLINT	
	, EventType		TINYINT
	, WhTicket		TINYINT
)
GO
